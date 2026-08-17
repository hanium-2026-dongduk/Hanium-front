import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/auth/login_screen.dart';
import 'package:hanium_front/screens/auth/signup_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 로그인 화면(P-AU-AU01)이 입력을 검증하고 Provider를 올바르게 부르는지 본다.
/// 통신은 하지 않고 AuthProvider 대신 가짜를 끼운다.
void main() {
  late FakeAuthProvider auth;

  setUp(() => auth = FakeAuthProvider());

  Future<void> pumpLogin(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
  }

  Future<void> tapLogin(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.pump();
  }

  testWidgets('빈 값으로 로그인하면 검증 메시지를 보여주고 요청하지 않는다', (tester) async {
    await pumpLogin(tester);

    await tapLogin(tester);

    expect(find.text('이메일을(를) 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호을(를) 입력해 주세요.'), findsOneWidget);
    expect(auth.loginCalls, isEmpty);
  });

  testWidgets('로그인은 이메일 형식을 따지지 않고 서버 판단에 맡긴다', (tester) async {
    // 가입 화면과 달리 여기서는 빈 값만 본다. 형식이 어긋나면 서버가 401로 답한다.
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'Password1!');
    await tapLogin(tester);

    expect(auth.loginCalls, [('not-an-email', 'Password1!')]);
  });

  testWidgets('제대로 입력하면 공백을 제거한 이메일로 로그인을 요청한다', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      '  user@example.com  ',
    );
    await tester.enterText(find.byType(TextFormField).last, 'Password1!');
    await tapLogin(tester);

    expect(auth.loginCalls, [
      // 비밀번호는 앞뒤 공백도 값의 일부라 다듬지 않는다.
      ('user@example.com', 'Password1!'),
    ]);
  });

  testWidgets('요청 중에는 버튼이 잠기고 로딩을 보여준다', (tester) async {
    auth.isSubmitting = true;
    await pumpLogin(tester);

    // 로딩 중에는 라벨 대신 인디케이터가 뜬다.
    expect(find.text('로그인'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('서버가 보낸 오류 메시지를 화면에 그대로 보여준다', (tester) async {
    auth.errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
    await pumpLogin(tester);

    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
  });

  testWidgets('회원가입 버튼을 누르면 회원가입 화면으로 간다', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('아직 계정이 없나요?  회원가입'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
