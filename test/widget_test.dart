import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/auth_gate.dart';
import 'package:hanium_front/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

/// AuthGate가 상태에 따라 올바른 화면을 고르는지 확인한다.
/// 실제 통신은 하지 않고 AuthProvider 대신 가짜 구현을 끼워 넣는다.
class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  AuthStatus status;

  _FakeAuthProvider(this.status);

  // 화면이 build에서 읽는 값들. 나머지 멤버는 이 테스트에서 호출되지 않는다.
  @override
  bool get isSubmitting => false;

  @override
  String? get errorMessage => null;

  @override
  User? get user => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget wrap(_FakeAuthProvider auth) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: const MaterialApp(home: AuthGate()),
    );
  }

  testWidgets('토큰 확인 중에는 로딩만 보여준다', (tester) async {
    await tester.pumpWidget(wrap(_FakeAuthProvider(AuthStatus.unknown)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('로그인 상태가 아니면 로그인 화면으로 간다', (tester) async {
    await tester.pumpWidget(
      wrap(_FakeAuthProvider(AuthStatus.unauthenticated)),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
