import 'package:flutter/foundation.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';

/// 화면 테스트용 가짜 AuthProvider.
///
/// 실제 통신 대신 호출을 기록하고, 화면이 읽는 상태값은 테스트에서 직접 세팅한다.
/// [AuthProvider]를 implements 하므로 화면 코드는 진짜와 구분하지 못한다.
class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  FakeAuthProvider({
    this.status = AuthStatus.unauthenticated,
    this.isSubmitting = false,
    this.errorMessage,
    this.user,
  });

  @override
  AuthStatus status;

  @override
  bool isSubmitting;

  @override
  String? errorMessage;

  @override
  User? user;

  /// 각 호출을 인자까지 기록해 화면이 무엇을 넘겼는지 확인한다.
  final List<(String email, String password)> loginCalls = [];
  final List<(String email, String password)> signupCalls = [];
  final List<String> sendSignupCodeCalls = [];
  final List<(String email, String code)> verifySignupCodeCalls = [];
  final List<String> sendPasswordResetCodeCalls = [];
  final List<(String email, String code, String newPassword)>
  resetPasswordCalls = [];
  int logoutCalls = 0;

  /// 각 동작이 성공했다고 할지. 실패 흐름을 볼 때 false로 바꾼다.
  bool loginResult = true;
  bool signupResult = true;
  bool sendSignupCodeResult = true;
  bool verifySignupCodeResult = true;
  bool sendPasswordResetCodeResult = true;
  bool resetPasswordResult = true;

  @override
  Future<bool> login({required String email, required String password}) async {
    loginCalls.add((email, password));
    return loginResult;
  }

  @override
  Future<bool> signup({
    required String email,
    required String password,
  }) async {
    signupCalls.add((email, password));
    return signupResult;
  }

  @override
  Future<bool> sendSignupCode(String email) async {
    sendSignupCodeCalls.add(email);
    return sendSignupCodeResult;
  }

  @override
  Future<bool> verifySignupCode({
    required String email,
    required String code,
  }) async {
    verifySignupCodeCalls.add((email, code));
    return verifySignupCodeResult;
  }

  @override
  Future<bool> sendPasswordResetCode(String email) async {
    sendPasswordResetCodeCalls.add(email);
    return sendPasswordResetCodeResult;
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    resetPasswordCalls.add((email, code, newPassword));
    return resetPasswordResult;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> handleSessionExpired() async {}

  /// 위에 없는 멤버는 이 테스트들에서 호출되지 않는다.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
