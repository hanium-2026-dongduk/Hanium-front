import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/settings/change_password_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 비밀번호 변경 화면(P-TU-ST06)은 로그인 상태라 이메일 입력 없이 곧바로
/// 인증번호를 요청하고, 이후 흐름은 비밀번호 재설정(AU03)과 같은 API를 쓴다.
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

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  /// 1단계를 통과해 인증번호·비밀번호 입력 화면까지 간다.
  Future<void> reachConfirmStep(WidgetTester tester) async {
    await tapAction(tester, '인증번호 받기');
  }

  group('1단계는', () {
    testWidgets('이메일을 다시 묻지 않고 로그인된 이메일로 곧바로 보낸다', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('parent@example.com'), findsOneWidget);

      await tapAction(tester, '인증번호 받기');

      expect(auth.sendPasswordResetCodeCalls, ['parent@example.com']);
      expect(find.widgetWithText(ElevatedButton, '비밀번호 바꾸기'), findsOneWidget);
    });

    testWidgets('발송에 실패하면(쿨다운 등) 단계를 넘기지 않는다', (tester) async {
      auth.sendPasswordResetCodeResult = false;
      await pumpScreen(tester);

      await tapAction(tester, '인증번호 받기');

      expect(find.widgetWithText(ElevatedButton, '인증번호 받기'), findsOneWidget);
    });
  });

  group('2단계는', () {
    testWidgets('6자리가 아닌 인증번호는 보내지 않는다', (tester) async {
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '123');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('인증번호는 숫자 6자리예요.'), findsOneWidget);
      expect(auth.resetPasswordCalls, isEmpty);
    });

    testWidgets('서버 정책에 못 미치는 비밀번호는 보내지 않는다', (tester) async {
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      // 특수문자가 없다.
      await tester.enterText(find.byType(TextFormField).at(1), 'abcdefg1');
      await tester.enterText(find.byType(TextFormField).at(2), 'abcdefg1');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('특수문자를 1자 이상 넣어 주세요.'), findsOneWidget);
      expect(auth.resetPasswordCalls, isEmpty);
    });

    testWidgets('비밀번호 확인이 다르면 보내지 않는다', (tester) async {
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password2!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(auth.resetPasswordCalls, isEmpty);
    });

    testWidgets('제대로 입력하면 로그인된 이메일·인증번호·새 비밀번호를 함께 보낸다', (tester) async {
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(auth.resetPasswordCalls, [
        ('parent@example.com', '123456', 'Password1!'),
      ]);
    });

    testWidgets('성공하면 안내 다이얼로그를 보여준 뒤 로그아웃한다', (tester) async {
      // 서버가 기존 세션을 전부 끊으므로 로컬 세션도 함께 정리해야 한다.
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('비밀번호가 변경되었어요'), findsOneWidget);
      expect(auth.logoutCalls, 0); // 아직 확인을 누르지 않았다.

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(auth.logoutCalls, 1);
    });

    testWidgets('실패하면 다이얼로그 없이 오류만 보여준다', (tester) async {
      auth
        ..resetPasswordResult = false
        ..errorMessage = '인증번호가 만료되었습니다.';
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
      await tapAction(tester, '비밀번호 바꾸기');

      expect(find.text('인증번호가 만료되었습니다.'), findsOneWidget);
      expect(find.text('비밀번호가 변경되었어요'), findsNothing);
      expect(auth.logoutCalls, 0);
    });

    testWidgets('인증번호를 다시 받으면 같은(로그인된) 이메일로 재발송한다', (tester) async {
      await pumpScreen(tester);
      await reachConfirmStep(tester);

      await tester.tap(find.text('인증번호 다시 받기'));
      await tester.pumpAndSettle();

      expect(auth.sendPasswordResetCodeCalls, [
        'parent@example.com',
        'parent@example.com',
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
