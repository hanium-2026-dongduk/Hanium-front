import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/profile_list_screen.dart';

/// 로그인 상태에 따라 첫 화면을 정한다.
///
/// 화면마다 "토큰 있나?"를 확인하지 않아도 되도록 여기 한곳에서만 분기한다.
/// 메인 화면(#6)이 붙으면 [AuthStatus.authenticated] 쪽만 바꿔주면 된다.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
