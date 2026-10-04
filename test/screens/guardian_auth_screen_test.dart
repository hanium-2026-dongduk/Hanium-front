import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

// 실제 앱에서 사용하는 파일들 import
import 'package:hanium_front/screens/auth/guardian_auth_screen.dart';
import 'package:hanium_front/services/guardian_service.dart';
import 'package:hanium_front/providers/guardian_provider.dart';

// -----------------------------------------------------------------------------
// 1. 가짜(Fake) 의존성 만들기
// -----------------------------------------------------------------------------

/// 서버 통신을 흉내내는 Fake Service
class FakeGuardianService implements GuardianService {
  bool hasPinToReturn = true;
  bool shouldThrow429 = false; // 5회 오답 테스트용 플래그

  @override
  Future<Map<String, dynamic>> getSettings() async {
    return {'has_pin': hasPinToReturn};
  }

  @override
  Future<String> verifyPassword(String password) async {
    if (shouldThrow429) _throw429Error();
    return "fake_reauth_token";
  }

  @override
  Future<void> setupPin({required String pin, String? reauthToken, String? guardianToken}) async {
    // 성공했다고 가정
  }

  @override
  Future<String> verifyPin(String pin) async {
    if (shouldThrow429) _throw429Error();
    return "fake_guardian_token";
  }

  // ✨ 에러의 원인! 새롭게 추가했던 함수를 Fake에도 껍데기만 만들어줌
  @override
  Future<void> updateSettings({
    required int limitMinutes,
    required bool pushEnabled,
    required String guardianToken,
  }) async {
    // 테스트용이므로 아무 작업도 하지 않음
  }

  void _throw429Error() {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      response: Response(requestOptions: RequestOptions(path: ''), statusCode: 429),
    );
  }
}

/// 상태 저장을 흉내내는 Fake Provider
class FakeGuardianProvider extends ChangeNotifier implements GuardianProvider {
  String? savedToken;

  @override
  String? get guardianToken => savedToken;

  @override
  bool get isAuthenticated => savedToken != null;

  @override
  void setToken(String token) {
    savedToken = token;
    notifyListeners();
  }

  @override
  void clearToken() {
    savedToken = null;
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// 2. 위젯 테스트 코드
// -----------------------------------------------------------------------------

void main() {
  late FakeGuardianService fakeService;
  late FakeGuardianProvider fakeProvider;

  setUp(() {
    fakeService = FakeGuardianService();
    fakeProvider = FakeGuardianProvider();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        Provider<GuardianService>.value(value: fakeService),
        ChangeNotifierProvider<GuardianProvider>.value(value: fakeProvider),
      ],
      child: const MaterialApp(
        home: GuardianAuthScreen(),
      ),
    );
  }

  group('GuardianAuthScreen 위젯 테스트', () {

    testWidgets('has_pin이 true이면 PIN 입력 화면이 렌더링된다', (WidgetTester tester) async {
      fakeService.hasPinToReturn = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('보호자 PIN 입력'), findsOneWidget);
    });

    testWidgets('has_pin이 false이면 비밀번호 입력 화면이 렌더링된다', (WidgetTester tester) async {
      fakeService.hasPinToReturn = false;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('보호자 계정 비밀번호'), findsOneWidget);
    });

    testWidgets('비밀번호 확인 후 새로운 PIN 설정 화면으로 넘어간다', (WidgetTester tester) async {
      fakeService.hasPinToReturn = false;
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'myPassword123!');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('새로운 PIN 설정'), findsOneWidget);
    });

    testWidgets('5회 오답 시 429 에러 메시지를 표시한다', (WidgetTester tester) async {
      fakeService.hasPinToReturn = true;
      fakeService.shouldThrow429 = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('연속 5회 실패하여 10분간 잠겼습니다.'), findsOneWidget);
    });

  });
}
