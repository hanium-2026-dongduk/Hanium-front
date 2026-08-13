import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

/// 앱 전체가 공유하는 Dio 인스턴스.
///
/// - 모든 요청에 `Authorization: Bearer ...` 헤더를 자동으로 붙인다.
/// - 401을 받으면 리프레시 토큰으로 한 번 갱신한 뒤 원래 요청을 재시도한다.
/// - 갱신까지 실패하면 토큰을 지우고 [onSessionExpired]로 알린다.
class ApiClient {
  final TokenStorage _tokenStorage;

  /// 세션이 끊겼을 때 호출된다. AuthProvider가 로그인 화면으로 되돌리는 용도라
  /// 순환 참조를 피하려고 생성 후에 주입한다. (main.dart 참고)
  Future<void> Function()? onSessionExpired;

  late final Dio dio;

  /// 토큰 갱신 전용 Dio. 인터셉터가 없어서 401 처리가 재귀로 돌지 않는다.
  late final Dio _refreshDio;

  /// 여러 요청이 동시에 401을 받아도 갱신은 한 번만 돌도록 잡아두는 자리.
  Future<bool>? _pendingRefresh;

  ApiClient({required this._tokenStorage, this.onSessionExpired}) {
    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
    );

    dio = Dio(options);
    _refreshDio = Dio(options);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _attachAccessToken,
        onError: _retryAfterRefresh,
      ),
    );
  }

  Future<void> _attachAccessToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  Future<void> _retryAfterRefresh(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // 로그인/회원가입 실패(401)는 갱신 대상이 아니고, 이미 재시도한 요청도 제외한다.
    final canRetry =
        error.response?.statusCode == 401 &&
        !_isAuthEndpoint(error.requestOptions.path) &&
        error.requestOptions.extra[_retriedKey] != true;

    if (!canRetry) {
      handler.next(error);
      return;
    }

    if (!await _refreshOnce()) {
      await _tokenStorage.clear();
      await onSessionExpired?.call();
      handler.next(error);
      return;
    }

    try {
      final request = error.requestOptions;
      request.extra[_retriedKey] = true;
      // 재시도는 dio로 보내야 인터셉터가 새 액세스 토큰을 다시 붙여준다.
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// 이미 갱신이 진행 중이면 새로 호출하지 않고 그 결과를 같이 기다린다.
  Future<bool> _refreshOnce() {
    return _pendingRefresh ??= _refresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<bool> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final accessToken = response.data?['accessToken'] as String?;
      if (accessToken == null) return false;

      // 서버가 리프레시 토큰까지 새로 주면(rotation) 그것도 같이 저장한다.
      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: response.data?['refreshToken'] as String? ?? refreshToken,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/signup') ||
      path.contains('/auth/refresh');

  static const _retriedKey = 'retried';
}
