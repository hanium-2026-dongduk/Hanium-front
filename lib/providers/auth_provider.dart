import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

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
  final TokenStorage _tokenStorage;

  AuthProvider({required this._authService, required this._tokenStorage});

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
  /// 저장된 토큰이 아직 유효하면 로그인 화면을 건너뛴다.
  Future<void> bootstrap() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    try {
      // 토큰이 만료됐어도 ApiClient가 리프레시를 한 번 시도해준다.
      _user = await _authService.fetchMe();
      _setStatus(AuthStatus.authenticated);
    } on ApiException {
      await _tokenStorage.clear();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  /// P-AU-AU01 로그인. 성공하면 true.
  Future<bool> login({required String email, required String password}) {
    return _submit(
      () => _authService.login(email: email, password: password),
    );
  }

  /// P-AU-AU02 회원가입. 서버가 바로 토큰을 주므로 성공 시 로그인 상태가 된다.
  Future<bool> signup({
    required String email,
    required String password,
    required String name,
  }) {
    return _submit(
      () => _authService.signup(email: email, password: password, name: name),
    );
  }

  Future<void> logout() async {
    await _authService.logout();
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

  /// 로그인과 회원가입이 로딩/에러 처리를 똑같이 하므로 한곳에 모았다.
  Future<bool> _submit(Future<AuthResult> Function() request) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await request();
      await _tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      _user = result.user;
      _status = AuthStatus.authenticated;
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
