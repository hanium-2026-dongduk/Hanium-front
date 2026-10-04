import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/settings/change_password_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 비밀번호 변경 화면(P-TU-ST06)은 로그인 상태라 이메일 인증 없이
/// 현재 비밀번호 확인만으로 새 비밀번호로 바꾼다(UC-ST-03).
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
        child: const MaterialApp(home: ChangePasswordScreen()),
      ),
    );
  }

  /// 현재 비밀번호, 새 비밀번호, 새 비밀번호 확인 순서로 채운다.
  Future<void> fill(
    WidgetTester tester, {
    String current = 'Current1!',
    String next = 'Password1!',
    String? confirm,
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), current);
    await tester.enterText(find.byType(TextFormField).at(1), next);
    await tester.enterText(find.byType(TextFormField).at(2), confirm ?? next);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, '비밀번호 바꾸기'));
    await tester.pumpAndSettle();
  }

  testWidgets('이메일 인증 없이 현재·새·확인 비밀번호 입력란만 보여준다', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('현재 비밀번호'), findsOneWidget);
    expect(find.text('새 비밀번호'), findsOneWidget);
    expect(find.text('새 비밀번호 확인'), findsOneWidget);
    expect(find.textContaining('인증번호'), findsNothing);
  });

  group('입력 검증은', () {
    testWidgets('현재 비밀번호가 비어 있으면 보내지 않는다', (tester) async {
      await pumpScreen(tester);

      await fill(tester, current: '');
      await submit(tester);

      expect(find.text('현재 비밀번호를 입력해 주세요.'), findsOneWidget);
      expect(auth.changePasswordCalls, isEmpty);
    });

    testWidgets('서버 정책에 못 미치는 새 비밀번호는 보내지 않는다', (tester) async {
      await pumpScreen(tester);

      // 특수문자가 없다.
      await fill(tester, next: 'abcdefg1');
      await submit(tester);

      expect(find.text('특수문자를 1자 이상 넣어 주세요.'), findsOneWidget);
      expect(auth.changePasswordCalls, isEmpty);
    });

    testWidgets('새 비밀번호가 현재와 같으면 보내지 않는다', (tester) async {
      await pumpScreen(tester);

      await fill(tester, current: 'Password1!', next: 'Password1!');
      await submit(tester);

      expect(find.text('지금 쓰는 비밀번호와 다르게 정해 주세요.'), findsOneWidget);
      expect(auth.changePasswordCalls, isEmpty);
    });

    testWidgets('새 비밀번호 확인이 다르면 보내지 않는다', (tester) async {
      await pumpScreen(tester);

      await fill(tester, confirm: 'Password2!');
      await submit(tester);

      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(auth.changePasswordCalls, isEmpty);
    });
  });

  testWidgets('제대로 입력하면 현재·새 비밀번호를 함께 보낸다', (tester) async {
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(auth.changePasswordCalls, [('Current1!', 'Password1!')]);
  });

  testWidgets('성공하면 안내 다이얼로그를 보여준 뒤 로그아웃한다', (tester) async {
    // 서버가 기존 세션을 전부 끊으므로 로컬 세션도 함께 정리해야 한다.
    await pumpScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text('비밀번호가 변경되었어요'), findsOneWidget);
    expect(auth.logoutCalls, 0); // 아직 확인을 누르지 않았다.

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
  });

  testWidgets('현재 비밀번호가 틀리면 다이얼로그 없이 오류만 보여준다', (tester) async {
    auth
      ..changePasswordResult = false
      ..errorMessage = '현재 비밀번호가 일치하지 않습니다.';
    await pumpScreen(tester);

    await fill(tester, current: 'Wrong123!');
    await submit(tester);

    expect(find.text('현재 비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(find.text('비밀번호가 변경되었어요'), findsNothing);
    expect(auth.logoutCalls, 0);
  });

  testWidgets('요청 중에는 버튼이 잠긴다', (tester) async {
    auth.isSubmitting = true;
    await pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
