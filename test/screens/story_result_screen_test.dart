import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/models/story_payload.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/quiz/quiz_screen.dart';
import 'package:hanium_front/screens/story_result_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/quiz_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:hanium_front/services/tts_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_flutter_tts.dart';
import '../support/fake_quiz_service.dart';

/// 동화 읽기 화면에서 퀴즈로 이어지는 진입(QZ02)을 본다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardService implements RewardService {
  @override
  Future<RewardDetail> fetchDetail(int childProfileId) async =>
      RewardDetail(childProfileId: childProfileId, points: 0, level: 1, streakDays: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<FakeQuizService> _pumpResult(WidgetTester tester, {int? storyId}) async {
  // 화면 전체가 들어오도록 넉넉한 가로 화면으로 그린다.
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // 표지 이미지는 네트워크에서 받는데 테스트에서는 항상 실패한다. 화면 동작과 무관하므로 무시한다.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('picsum.photos')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  final quizService = FakeQuizService();
  final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
    ..setActiveChild(const ChildProfile(childProfileId: 3, childName: '첫째'));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<RewardProvider>(
          create: (_) => RewardProvider(rewardService: _FakeRewardService()),
        ),
        Provider<QuizService>.value(value: quizService),
        Provider<TtsService>(create: (_) => TtsService(flutterTts: FakeFlutterTts())),
      ],
      child: MaterialApp(
        home: StoryResultScreen(payload: StoryCreatePayload(), storyId: storyId),
      ),
    ),
  );
  await tester.pump();
  return quizService;
}

void main() {
  testWidgets('저장된 동화 id가 없으면 퀴즈 버튼이 꺼져 있고 이유를 안내한다', (tester) async {
    await _pumpResult(tester);

    final button = tester.widget<ButtonStyleButton>(find.widgetWithText(ElevatedButton, '퀴즈 풀기'));
    expect(button.onPressed, isNull);
    expect(find.text('동화가 저장되면 퀴즈를 풀 수 있어요.'), findsOneWidget);
  });

  testWidgets('동화 id가 있으면 퀴즈 풀기로 퀴즈 화면을 연다', (tester) async {
    await _pumpResult(tester, storyId: 11);

    await tester.tap(find.text('퀴즈 풀기'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Where did the bunny go?'), findsOneWidget);
  });

  testWidgets('퀴즈를 건너뛰고 돌아오면 다시 풀 수 있다', (tester) async {
    await _pumpResult(tester, storyId: 11);

    await tester.tap(find.text('퀴즈 풀기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candy Forest'));
    await tester.pump();
    await tester.tap(find.text('퀴즈 건너뛰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그만할래요')); // 답을 골랐다면 실수로 나가지 않도록 확인창이 먼저 뜬다.
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsNothing);
    final button = tester.widget<ButtonStyleButton>(find.widgetWithText(ElevatedButton, '퀴즈 풀기'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('퀴즈를 끝까지 풀고 돌아오면 다시 열 수 없다 (포인트 중복 지급 방지)', (tester) async {
    final quizService = await _pumpResult(tester, storyId: 11);

    await tester.tap(find.text('퀴즈 풀기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candy Forest'));
    await tester.pump();
    await tester.tap(find.text('다음 →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A little bird'));
    await tester.pump();
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();
    // 포인트를 받아 뜬 축하 연출이 저절로 닫히길 기다린다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsNothing);
    expect(find.text('퀴즈를 마쳤어요'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.widgetWithText(ElevatedButton, '퀴즈를 마쳤어요'),
    );
    expect(button.onPressed, isNull);
    expect(quizService.submitCalls, 1);
    expect(quizService.generateCalls, 1);
  });
}
