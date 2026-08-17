import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/auth/signup_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 회원가입 화면(P-AU-AU02)은 서버 계약상 3단계를 순서대로 밟아야 한다.
///   1. 이메일 입력 → 인증번호 발송
///   2. 인증번호 확인
///   3. 비밀번호 정하고 가입
/// 단계를 건너뛰거나 잘못된 값으로 넘어가지 않는지 확인한다.
void main() {
  late FakeAuthProvider auth;

  setUp(() => auth = FakeAuthProvider());

  Future<void> pumpSignup(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  /// 1단계를 통과해 인증번호 입력 화면까지 간다.
  Future<void> reachCodeStep(
    WidgetTester tester, {
    String email = 'user@example.com',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tapAction(tester, '인증번호 받기');
  }

  /// 2단계까지 통과해 비밀번호 입력 화면까지 간다.
  Future<void> reachPasswordStep(WidgetTester tester) async {
    await reachCodeStep(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tapAction(tester, '인증번호 확인');
  }

  group('1단계는', () {
    testWidgets('처음에는 이메일만 묻고 1/3 단계로 안내한다', (tester) async {
      await pumpSignup(tester);

      expect(find.text('1 / 3 단계'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '인증번호 받기'), findsOneWidget);
    });

    testWidgets('이메일 형식이 틀리면 발송하지 않는다', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tapAction(tester, '인증번호 받기');

      expect(find.text('이메일 형식이 올바르지 않아요.'), findsOneWidget);
      expect(auth.sendSignupCodeCalls, isEmpty);
      expect(find.text('1 / 3 단계'), findsOneWidget);
    });

    testWidgets('발송에 성공하면 2단계로 넘어간다', (tester) async {
      await pumpSignup(tester);

      await reachCodeStep(tester);

      expect(auth.sendSignupCodeCalls, ['user@example.com']);
      expect(find.text('2 / 3 단계'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '인증번호 확인'), findsOneWidget);
    });

    testWidgets('발송에 실패하면 단계를 넘기지 않는다', (tester) async {
      auth.sendSignupCodeResult = false;
      await pumpSignup(tester);

      await reachCodeStep(tester);

      expect(find.text('1 / 3 단계'), findsOneWidget);
    });
  });

  group('2단계는', () {
    testWidgets('인증을 마친 이메일은 더 이상 못 바꾸게 잠근다', (tester) async {
      await pumpSignup(tester);
      await reachCodeStep(tester);

      final emailField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(emailField.enabled, isFalse);
    });

    testWidgets('6자리가 아닌 인증번호는 보내지 않는다', (tester) async {
      await pumpSignup(tester);
      await reachCodeStep(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tapAction(tester, '인증번호 확인');

      expect(find.text('인증번호는 숫자 6자리예요.'), findsOneWidget);
      expect(auth.verifySignupCodeCalls, isEmpty);
    });

    testWidgets('검증에 성공하면 3단계로 넘어간다', (tester) async {
      await pumpSignup(tester);

      await reachPasswordStep(tester);

      expect(auth.verifySignupCodeCalls, [('user@example.com', '123456')]);
      expect(find.text('3 / 3 단계'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '가입하기'), findsOneWidget);
    });

    testWidgets('인증번호를 다시 받으면 같은 이메일로 재발송한다', (tester) async {
      await pumpSignup(tester);
      await reachCodeStep(tester);

      await tester.tap(find.text('인증번호 다시 받기'));
      await tester.pumpAndSettle();

      expect(auth.sendSignupCodeCalls, [
        'user@example.com',
        'user@example.com',
      ]);
      // 재발송해도 단계는 그대로여야 한다.
      expect(find.text('2 / 3 단계'), findsOneWidget);
    });
  });

  group('3단계는', () {
    testWidgets('서버 정책에 못 미치는 비밀번호는 보내지 않는다', (tester) async {
      await pumpSignup(tester);
      await reachPasswordStep(tester);

      // 특수문자가 없다. 서버도 같은 이유로 400을 낸다.
      await tester.enterText(find.byType(TextFormField).at(2), 'abcdefg1');
      await tester.enterText(find.byType(TextFormField).at(3), 'abcdefg1');
      await tapAction(tester, '가입하기');

      expect(find.text('특수문자를 1자 이상 넣어 주세요.'), findsOneWidget);
      expect(auth.signupCalls, isEmpty);
    });

    testWidgets('비밀번호 확인이 다르면 보내지 않는다', (tester) async {
      await pumpSignup(tester);
      await reachPasswordStep(tester);

      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password2!');
      await tapAction(tester, '가입하기');

      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(auth.signupCalls, isEmpty);
    });

    testWidgets('제대로 입력하면 가입을 요청한다', (tester) async {
      await pumpSignup(tester);
      await reachPasswordStep(tester);

      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');
      await tapAction(tester, '가입하기');

      // 서버 users에 이름 컬럼이 없으므로 이메일과 비밀번호만 넘긴다.
      expect(auth.signupCalls, [('user@example.com', 'Password1!')]);
    });
  });

  testWidgets('요청 중에는 버튼이 잠긴다', (tester) async {
    auth.isSubmitting = true;
    await pumpSignup(tester);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('서버가 보낸 오류 메시지를 화면에 보여준다', (tester) async {
    auth.errorMessage = '이미 가입된 이메일입니다.';
    await pumpSignup(tester);

    expect(find.text('이미 가입된 이메일입니다.'), findsOneWidget);
  });
}
