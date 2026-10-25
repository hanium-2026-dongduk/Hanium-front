import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/profile_list_screen.dart';

/// 로그인 상태에 따라 첫 화면을 정한다.
///
/// 화면마다 "토큰 있나?"를 확인하지 않아도 되도록 여기 한곳에서만 분기한다.
/// 메인 화면(#6)이 붙으면 [AuthStatus.authenticated] 쪽만 바꿔주면 된다.
///
/// 로그아웃·비밀번호 변경·세션 만료로 로그아웃 상태가 되면, 이 위에 push된 화면
/// (계정 보안, 동화 생성 등)을 모두 닫는다. 이 화면은 자기 자리만 로그인 화면으로
/// 바꾸므로, 닫지 않으면 위에 쌓인 화면이 그대로 남아 로그인 화면을 가린다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthProvider _auth;
  late AuthStatus _lastStatus;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _lastStatus = _auth.status;
    _auth.addListener(_closeScreensOnLogout);
  }

  @override
  void dispose() {
    _auth.removeListener(_closeScreensOnLogout);
    super.dispose();
  }

  void _closeScreensOnLogout() {
    final status = _auth.status;
    final loggedOut =
        status == AuthStatus.unauthenticated && _lastStatus != status;
    _lastStatus = status;
    if (loggedOut && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    switch (status) {
      case AuthStatus.unknown:
        // 저장된 토큰을 확인하는 아주 짧은 구간. 나중에 스플래시 화면으로 교체.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const ProfileListScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
