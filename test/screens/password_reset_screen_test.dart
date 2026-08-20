import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/auth/password_reset_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 비밀번호 재설정 화면(P-AU-AU03)은 서버 계약상 2단계다.
/// 회원가입과 달리 인증번호만 확인하는 단계가 없고, 인증번호와 새 비밀번호를 함께 보낸다.
void main() {
  late FakeAuthProvider auth;

  setUp(() => auth = FakeAuthProvider());

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: PasswordResetScreen()),
      ),
    );
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  /// 1단계를 통과해 인증번호·비밀번호 입력 화면까지 간다.
  Future<void> reachResetStep(
    WidgetTester tester, {
    String email = 'user@example.com',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tapAction(tester, '인증번호 받기');
  }

  group('1단계는', () {
    testWidgets('이메일만 묻는다', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '인증번호 받기'), findsOneWidget);
    });

    testWidgets('가입 여부를 알려주지 않는다는 안내를 보여준다', (tester) async {
      // 서버가 계정 열거 방지를 위해 항상 같은 응답을 주므로, 사용자가 오해하지 않도록
      // 화면에서 미리 알려준다.
      await pumpScreen(tester);

      expect(find.textContaining('가입되지 않은 이메일이어도'), findsOneWidget);
    });

    testWidgets('이메일 형식이 틀리면 보내지 않는다', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tapAction(tester, '인증번호 받기');

      expect(find.text('이메일 형식이 올바르지 않아요.'), findsOneWidget);
      expect(auth.sendPasswordResetCodeCalls, isEmpty);
    });

    testWidgets('발송에 성공하면 2단계로 넘어간다', (tester) async {
      await pumpScreen(tester);

      await reachResetStep(tester);

      expect(auth.sendPasswordResetCodeCalls, ['user@example.com']);
      expect(find.widgetWithText(ElevatedButton, '비밀번호 바꾸기'), findsOneWidget);
    });

    testWidgets('발송에 실패하면(쿨다운 등) 단계를 넘기지 않는다', (tester) async {
      auth.sendPasswordResetCodeResult = false;
      await pumpScreen(tester);

      await reachResetStep(tester);

      expect(find.widgetWithText(ElevatedButton, '인증번호 받기'), findsOneWidget);
    });
  });

  group('2단계는', () {
    testWidgets('인증번호를 받은 이메일은 못 바꾸게 잠근다', (tester) async {
      await pumpScreen(tester);
      await reachResetStep(tester);

      final emailField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(emailField.enabled, isFalse);
    });

    testWidgets('6자리가 아닌 인증번호는 보내지 않는다', (tester) async {
      await pumpScreen(tester);
      await reachResetStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('인증번호는 숫자 6자리예요.'), findsOneWidget);
      expect(auth.resetPasswordCalls, isEmpty);
    });

    testWidgets('서버 정책에 못 미치는 비밀번호는 보내지 않는다', (tester) async {
      await pumpScreen(tester);
      await reachResetStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      // 특수문자가 없다.
      await tester.enterText(find.byType(TextFormField).at(2), 'abcdefg1');
      await tester.enterText(find.byType(TextFormField).at(3), 'abcdefg1');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('특수문자를 1자 이상 넣어 주세요.'), findsOneWidget);
      expect(auth.resetPasswordCalls, isEmpty);
    });

    testWidgets('비밀번호 확인이 다르면 보내지 않는다', (tester) async {
      await pumpScreen(tester);
      await reachResetStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password2!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(auth.resetPasswordCalls, isEmpty);
    });

    testWidgets('제대로 입력하면 이메일·인증번호·새 비밀번호를 한 번에 보낸다', (tester) async {
      await pumpScreen(tester);
      await reachResetStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      // 서버가 검증과 변경을 한 트랜잭션으로 처리하므로 호출도 한 번뿐이다.
      expect(auth.resetPasswordCalls, [
        ('user@example.com', '123456', 'Password1!'),
      ]);
    });

    testWidgets('성공하면 화면을 닫고 다시 로그인하라고 알린다', (tester) async {
      // 서버가 기존 세션을 전부 끊기 때문에 자동 로그인시키지 않는다.
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PasswordResetScreen(),
                    ),
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tapAction(tester, '열기');
      await reachResetStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.byType(PasswordResetScreen), findsNothing);
      expect(find.textContaining('새 비밀번호로 로그인해 주세요'), findsOneWidget);
    });

    testWidgets('실패하면 화면을 닫지 않고 오류를 보여준다', (tester) async {
      auth
        ..resetPasswordResult = false
        ..errorMessage = '인증번호가 만료되었습니다.';
      await pumpScreen(tester);
      await reachResetStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.byType(PasswordResetScreen), findsOneWidget);
      expect(find.text('인증번호가 만료되었습니다.'), findsOneWidget);
    });

    testWidgets('인증번호를 다시 받으면 같은 이메일로 재발송한다', (tester) async {
      await pumpScreen(tester);
      await reachResetStep(tester);

      await tester.tap(find.text('인증번호 다시 받기'));
      await tester.pumpAndSettle();

      expect(auth.sendPasswordResetCodeCalls, [
        'user@example.com',
        'user@example.com',
      ]);
    });
  });

  testWidgets('요청 중에는 버튼이 잠긴다', (tester) async {
    auth.isSubmitting = true;
    await pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
