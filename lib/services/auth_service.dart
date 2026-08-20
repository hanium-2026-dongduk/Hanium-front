import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/user.dart';

/// 로그인이 성공했을 때 서버가 내려주는 묶음.
/// 회원가입은 토큰을 주지 않으므로 이 타입을 쓰지 않는다.
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
/// 계약은 Hanium-back `docs/API_SPEC_AUTH.md`가 기준이다.
///
/// 회원가입은 반드시 아래 순서를 지켜야 한다. 인증을 건너뛰고 signup을 부르면 403이다.
///   1. [sendSignupCode]  POST /auth/email/send
///   2. [verifySignupCode] POST /auth/email/verify
///   3. [signup]           POST /auth/signup
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// 1단계. 가입할 이메일로 6자리 인증번호를 보낸다.
  /// 이미 가입된 이메일이면 409, 재발송 쿨다운(60초) 중이면 429가 온다.
  Future<void> sendSignupCode(String email) async {
    await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/email/send',
        data: {'email': email},
      ),
    );
  }

  /// 2단계. 받은 인증번호를 검증한다. 유효시간은 5분이다.
  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/email/verify',
        data: {'email': email, 'code': code},
      ),
    );
  }

  /// 3단계. POST /api/auth/signup
  ///
  /// 서버는 사용자만 돌려주고 **토큰은 주지 않는다.** 가입 직후 로그인 상태로 만들려면
  /// 호출한 쪽에서 [login]을 이어서 불러야 한다.
  /// 서버 users에 이름 컬럼이 없어서 이름은 보내지 않는다.
  Future<User> signup({
    required String email,
    required String password,
  }) async {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/signup',
        data: {'email': email, 'password': password},
      ),
      (response) => User.fromJson(ApiResponse.nested(response, 'user')),
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
      (response) => AuthResult.fromJson(ApiResponse.data(response)),
    );
  }

  /// P-AU-AU03 비밀번호 재설정 1단계. 재설정용 인증번호를 보낸다.
  ///
  /// 가입되지 않은 이메일이어도 **200으로 같은 응답**이 온다(계정 열거 방지).
  /// 그러니 이 호출이 성공했다고 해서 계정이 있다는 뜻은 아니다.
  /// 쿨다운(60초) 중이면 429다.
  Future<void> sendPasswordResetCode(String email) async {
    await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/password/reset-request',
        data: {'email': email},
      ),
    );
  }

  /// P-AU-AU03 비밀번호 재설정 2단계.
  ///
  /// 인증번호 확인과 비밀번호 변경이 한 번에 처리된다. 회원가입과 달리 검증만 하는
  /// 단계가 따로 없다.
  ///
  /// 실패는 이유별로 상태 코드가 다르다.
  ///   400 인증번호 불일치(또는 가입되지 않은 이메일) · 410 만료 · 429 5회 초과
  ///
  /// 성공하면 그 계정의 리프레시 토큰이 전부 폐기되므로 다른 기기도 다시 로그인해야 한다.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _send(
      () => _apiClient.dio.put<Map<String, dynamic>>(
        '/auth/password/reset',
        data: {'email': email, 'code': code, 'newPassword': newPassword},
      ),
    );
  }

  /// POST /api/auth/logout — 서버가 해당 리프레시 토큰을 폐기한다.
  /// 바디에 refreshToken을 담아야 하며, 실패해도 앱은 어차피 로컬 토큰을 지우므로
  /// 예외를 삼킨다.
  Future<void> logout(String? refreshToken) async {
    if (refreshToken == null) return;
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      return;
    }
  }

  /// 응답 본문을 쓰지 않는 호출용.
  Future<void> _send(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Dio 예외를 화면에서 다루기 쉬운 [ApiException]으로 바꿔주는 공통 처리.
  Future<T> _call<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Response<Map<String, dynamic>> response) parse,
  ) async {
    try {
      return parse(await request());
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
