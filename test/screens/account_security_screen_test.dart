import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/settings/account_security_screen.dart';
import 'package:hanium_front/screens/settings/change_password_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 계정 보안 화면(P-TU-ST06)은 비밀번호 변경 진입과 로그아웃(확인 후 실행)을 다룬다.
void main() {
  const user = User(
    userId: 1,
    email: 'parent@example.com',
    role: 'parent',
    status: 'active',
  );

  late FakeAuthProvider auth;

  setUp(() {
    auth = FakeAuthProvider(status: AuthStatus.authenticated, user: user);
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: AccountSecurityScreen()),
      ),
    );
  }

  testWidgets('비밀번호 변경을 누르면 비밀번호 변경 화면으로 이동한다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('로그아웃은 확인 전에는 실행하지 않는다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 0);
  });

  testWidgets('로그아웃을 확인하면 Provider의 logout을 부른다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    // 다이얼로그의 '로그아웃' 버튼은 목록의 것과 텍스트가 같으므로 마지막 것을 누른다.
    await tester.tap(find.text('로그아웃').last);
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
  });
}
