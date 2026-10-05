import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

// 실제 앱에서 사용하는 파일들 import (경로는 프로젝트에 맞게 수정)
import 'package:hanium_front/screens/auth/guardian_auth_screen.dart';
import 'package:hanium_front/screens/parent_screen.dart';
import 'package:hanium_front/services/guardian_service.dart';
import 'package:hanium_front/providers/guardian_provider.dart';
import 'package:hanium_front/core/api_client.dart'; // ApiClient 임포트 필요할 수 있음

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

  // 매 테스트가 실행되기 전에 초기화
  setUp(() {
    fakeService = FakeGuardianService();
    fakeProvider = FakeGuardianProvider();
  });

  // 화면을 렌더링하기 위한 헬퍼 함수
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
      // 1. 환경 설정: 설정 조회 시 has_pin = true 반환
      fakeService.hasPinToReturn = true;

      // 2. 위젯 빌드 및 애니메이션 종료 대기
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(); // 비동기 _checkGuardianSettings 완료 대기

      // 3. 검증: '보호자 PIN 입력' 텍스트가 화면에 존재하는지 확인
      expect(find.text('보호자 PIN 입력'), findsOneWidget);
    });

    testWidgets('has_pin이 false이면 비밀번호 입력 화면이 렌더링된다', (WidgetTester tester) async {
      // 1. 환경 설정: 설정 조회 시 has_pin = false 반환
      fakeService.hasPinToReturn = false;

      // 2. 위젯 빌드 및 대기
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 3. 검증: '보호자 계정 비밀번호' 텍스트가 화면에 존재하는지 확인
      expect(find.text('보호자 계정 비밀번호'), findsOneWidget);
    });

    testWidgets('비밀번호 확인 후 새로운 PIN 설정 화면으로 넘어간다', (WidgetTester tester) async {
      fakeService.hasPinToReturn = false;
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 비밀번호 입력
      await tester.enterText(find.byType(TextField), 'myPassword123!');

      // 확인 버튼 탭
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle(); // 비동기 통신 및 상태 변경 대기

      // '새로운 PIN 설정' 화면으로 바뀌었는지 확인
      expect(find.text('새로운 PIN 설정'), findsOneWidget);
    });

    testWidgets('5회 오답 시 429 에러 메시지를 표시한다', (WidgetTester tester) async {
      fakeService.hasPinToReturn = true;
      fakeService.shouldThrow429 = true; // 통신 시 429 에러 발생하도록 설정

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // PIN 텍스트 필드에 입력
      await tester.enterText(find.byType(TextField), '1234');

      // 확인 버튼 탭
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // 에러 메시지 텍스트가 화면에 뜨는지 확인
      expect(find.text('연속 5회 실패하여 10분간 잠겼습니다.'), findsOneWidget);
    });

  });
}
