import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/user.dart';

/// 로그인/회원가입이 성공했을 때 서버가 내려주는 묶음.
class AuthResult {
  final User user;
  final String accessToken;
  final String refreshToken;

  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    user: User.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}

/// 인증 관련 API 호출만 담당한다. (P-AU-AU01 로그인, P-AU-AU02 회원가입)
///
/// 상태를 들고 있지 않으므로 화면에서 직접 쓰지 말고 AuthProvider를 통해 쓴다.
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// POST /api/auth/signup
  Future<AuthResult> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/signup',
        data: {'email': email, 'password': password, 'name': name},
      ),
      AuthResult.fromJson,
    );
  }

  /// POST /api/auth/login
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
      AuthResult.fromJson,
    );
  }

  /// GET /api/users/me — 저장된 토큰이 아직 살아있는지 확인할 때도 쓴다.
  Future<User> fetchMe() async {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>('/users/me'),
      User.fromJson,
    );
  }

  /// POST /api/auth/logout — 서버에서 리프레시 토큰을 폐기한다.
  /// 실패해도 앱은 어차피 로컬 토큰을 지우므로 예외를 삼킨다.
  Future<void> logout() async {
    try {
      await _apiClient.dio.post<void>('/auth/logout');
    } on DioException {
      return;
    }
  }

  /// Dio 예외를 화면에서 다루기 쉬운 [ApiException]으로 바꿔주는 공통 처리.
  Future<T> _call<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw const ApiException(message: '서버 응답이 비어 있어요.');
      }
      return parse(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
