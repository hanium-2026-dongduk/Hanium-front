import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// 앱이 지금 로그인 상태인지 나타낸다.
/// [unknown]은 아직 저장된 토큰을 확인하는 중이라는 뜻으로, 스플래시를 띄우는 구간이다.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// 로그인 상태를 앱 전체가 공유하기 위한 Provider.
///
/// 화면에서는 이렇게 쓴다.
/// ```dart
/// final auth = context.watch<AuthProvider>();          // 상태 구독
/// await context.read<AuthProvider>().login(...);       // 동작 호출
/// ```
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ProfileService _profileService;
  final TokenStorage _tokenStorage;

  AuthProvider({
    required this._authService,
    required this._profileService,
    required this._tokenStorage,
  });


  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;

  /// 로그인/회원가입 요청이 진행 중인지. 버튼 비활성화와 로딩 표시에 쓴다.
  bool get isSubmitting => _isSubmitting;

  /// 마지막 요청이 실패한 이유. 성공하거나 다시 시도하면 지워진다.
  String? get errorMessage => _errorMessage;

  /// 앱이 시작될 때 한 번 호출한다.
  ///
  /// 백엔드에 "내 정보" 엔드포인트가 없어서, 저장해둔 user를 복원한 뒤
  /// 인증이 필요한 API(`GET /api/children`)를 한 번 불러 토큰이 아직 살아있는지 확인한다.
  /// 액세스 토큰이 만료됐어도 ApiClient가 리프레시를 한 번 시도해준다.
  Future<void> bootstrap() async {
    final accessToken = await _tokenStorage.readAccessToken();
    final storedUser = await _tokenStorage.readUser();
    if (accessToken == null || storedUser == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    try {
      await _profileService.fetchProfiles();
      _user = storedUser;
      _setStatus(AuthStatus.authenticated);
    } on ApiException catch (error) {
      // 토큰 문제일 때만 로그아웃시킨다. 서버가 죽었거나 네트워크가 끊긴 것뿐이라면
      // 저장된 세션을 버리지 않고 그대로 들여보낸다.
      if (!error.isUnauthorized) {
        _user = storedUser;
        _setStatus(AuthStatus.authenticated);
        return;
      }
      await _tokenStorage.clear();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  /// P-AU-AU02 회원가입 1단계. 인증번호를 이메일로 보낸다.
  Future<bool> sendSignupCode(String email) {
    return _run(() => _authService.sendSignupCode(email));
  }

  /// P-AU-AU02 회원가입 2단계. 인증번호를 확인한다.
  Future<bool> verifySignupCode({
    required String email,
    required String code,
  }) {
    return _run(
      () => _authService.verifySignupCode(email: email, code: code),
    );
  }

  /// P-AU-AU02 회원가입 3단계.
  ///
  /// 서버가 가입 응답으로 토큰을 주지 않으므로, 가입에 성공하면 같은 자격증명으로
  /// 곧바로 로그인까지 해서 화면 흐름은 "가입하면 바로 로그인" 그대로 유지한다.
  Future<bool> signup({
    required String email,
    required String password,
  }) {
    return _run(() async {
      await _authService.signup(email: email, password: password);
      await _authenticate(
        () => _authService.login(email: email, password: password),
      );
    });
  }

  /// P-AU-AU01 로그인. 성공하면 true.
  Future<bool> login({required String email, required String password}) {
    return _run(
      () => _authenticate(
        () => _authService.login(email: email, password: password),
      ),
    );
  }

  /// P-AU-AU03 비밀번호 재설정 1단계. 재설정용 인증번호를 보낸다.
  Future<bool> sendPasswordResetCode(String email) {
    return _run(() => _authService.sendPasswordResetCode(email));
  }

  /// P-AU-AU03 비밀번호 재설정 2단계. 인증번호 확인과 변경이 한 번에 끝난다.
  ///
  /// 성공해도 로그인 상태로 만들지 않는다. 서버가 기존 세션을 전부 끊으므로
  /// 새 비밀번호로 다시 로그인해야 한다.
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _run(
      () => _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
  }

  Future<void> logout() async {
    // 서버가 폐기할 대상을 알아야 하므로 지우기 전에 읽어둔다.
    final refreshToken = await _tokenStorage.readRefreshToken();
    await _authService.logout(refreshToken);
    await _tokenStorage.clear();
    _user = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  /// 리프레시까지 실패해 세션이 끊겼을 때 ApiClient가 호출한다.
  /// 토큰은 ApiClient가 이미 지운 뒤라 여기서는 화면 상태만 되돌린다.
  Future<void> handleSessionExpired() async {
    if (_status == AuthStatus.unauthenticated) return;
    _user = null;
    _errorMessage = '로그인이 만료되었어요. 다시 로그인해 주세요.';
    _setStatus(AuthStatus.unauthenticated);
  }

  /// 로그인 결과를 저장하고 로그인 상태로 만든다.
  Future<void> _authenticate(Future<AuthResult> Function() request) async {
    final result = await request();
    await _tokenStorage.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _tokenStorage.saveUser(result.user);
    _user = result.user;
    _status = AuthStatus.authenticated;
  }

  /// 인증 화면의 요청들이 로딩/에러 처리를 똑같이 하므로 한곳에 모았다.
  Future<bool> _run(Future<void> Function() request) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await request();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
