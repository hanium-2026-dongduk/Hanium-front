import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';
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
  Future<_RefreshOutcome>? _pendingRefresh;

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
        !_isPublicEndpoint(error.requestOptions.path) &&
        error.requestOptions.extra[_retriedKey] != true;

    if (!canRetry) {
      handler.next(error);
      return;
    }

    switch (await _refreshOnce()) {
      case _RefreshOutcome.succeeded:
        break;
      case _RefreshOutcome.rejected:
        // 서버가 리프레시 토큰을 거절했다. 다시 로그인하는 수밖에 없다.
        await _tokenStorage.clear();
        await onSessionExpired?.call();
        handler.next(error);
        return;
      case _RefreshOutcome.unreachable:
        // 서버에 닿지 못했을 뿐 토큰이 무효라는 뜻은 아니다. 지우면 네트워크가
        // 잠깐 끊긴 것만으로 멀쩡한 세션이 로그아웃된다.
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
  Future<_RefreshOutcome> _refreshOnce() {
    return _pendingRefresh ??= _refresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<_RefreshOutcome> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return _RefreshOutcome.rejected;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      // 응답은 { success, message, data: { accessToken, refreshToken } } 봉투에 담겨 온다.
      final data = ApiResponse.data(response);
      final accessToken = data['accessToken'] as String?;
      final rotated = data['refreshToken'] as String?;
      // 서버 계약상 둘 다 오게 되어 있다. 하나라도 없으면 다음 갱신이 불가능하다.
      if (accessToken == null || rotated == null) {
        return _RefreshOutcome.rejected;
      }

      // 서버는 리프레시 토큰을 항상 회전시킨다. 요청에 쓴 토큰은 이미 폐기됐으므로
      // 새로 받은 것을 반드시 저장해야 다음 갱신이 된다.
      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: rotated,
      );
      return _RefreshOutcome.succeeded;
    } on DioException catch (error) {
      // 서버가 "이 토큰 못 쓴다"고 답한 것과, 서버에 닿지도 못한 것은 다르다.
      return _isNetworkFailure(error)
          ? _RefreshOutcome.unreachable
          : _RefreshOutcome.rejected;
    } on ApiException {
      // 응답은 왔는데 형식이 어긋난 경우. 갱신은 실패다.
      return _RefreshOutcome.rejected;
    }
  }

  /// 응답을 받지 못한 실패인지. 이 경우 토큰의 유효성은 알 수 없다.
  static bool _isNetworkFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // 소켓 오류 등 Dio가 분류하지 못한 것도 응답이 없으면 네트워크 문제로 본다.
        return error.response == null;
      default:
        return false;
    }
  }

  /// `/api/auth/*`는 전부 토큰 없이 호출하는 엔드포인트라 401을 받아도 갱신 대상이 아니다.
  /// (로그인 실패, 만료된 인증번호 등은 그냥 실패여야 한다)
  /// 토큰 없이 부르는 엔드포인트인지. 여기서 401이 나면 "인증 실패"라는 뜻이므로
  /// 갱신 대상이 아니다. (로그인 실패, 만료된 인증번호 등)
  ///
  /// `/auth/` 전체를 제외하지 않고 하나씩 나열하는 이유는, 나중에 토큰이 필요한
  /// `/auth/*` 엔드포인트(예: 비밀번호 변경)가 생겼을 때 그것까지 조용히 갱신 대상에서
  /// 빠지는 것을 막기 위해서다. 새 비인증 엔드포인트를 추가하면 여기에도 넣어야 한다.
  bool _isPublicEndpoint(String path) =>
      _publicEndpoints.any((endpoint) => path.endsWith(endpoint));

  /// 상대 경로(`/auth/login`)로도, 절대 URL로도 걸리도록 끝부분으로 비교한다.
  static const _publicEndpoints = [
    '/auth/login',
    '/auth/signup',
    '/auth/refresh',
    '/auth/logout',
    '/auth/email/send',
    '/auth/email/verify',
    '/auth/password/reset-request',
    '/auth/password/reset',
  ];

  static const _retriedKey = 'retried';
}

/// 토큰 갱신 시도의 결과.
///
/// [rejected]와 [unreachable]을 구분해야 한다. 서버가 토큰을 거절한 것과 서버에
/// 닿지 못한 것은 다르고, 후자에서 토큰을 지우면 네트워크가 잠깐 끊긴 것만으로
/// 멀쩡한 세션이 로그아웃된다.
enum _RefreshOutcome { succeeded, rejected, unreachable }
