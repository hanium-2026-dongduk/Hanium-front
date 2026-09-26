import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/quiz/quiz_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/quiz_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:hanium_front/services/tts_service.dart';
import 'package:hanium_front/widgets/reward_celebration.dart';
import 'package:provider/provider.dart';

import '../support/fake_flutter_tts.dart';
import '../support/fake_quiz_service.dart';

/// 동화 확인 퀴즈 화면(QZ01~QZ03)이 응시·채점·보상 연출을 제대로 다루는지 본다.
/// 통신은 하지 않고 QuizService·RewardService 대신 가짜를 끼운다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardService implements RewardService {
  int level = 1;
  int refreshCalls = 0;

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) async {
    refreshCalls++;
    return RewardDetail(childProfileId: childProfileId, points: 100, level: level, streakDays: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  final FakeQuizService quizService;
  final _FakeRewardService rewardService;
  final FakeFlutterTts tts;

  /// 퀴즈 화면이 닫힐 때 돌려준 값. 아직 안 닫혔으면 null.
  bool? poppedWith;
  bool popped = false;

  _Harness(this.quizService, this.rewardService, this.tts);
}

Future<_Harness> _pumpQuiz(
  WidgetTester tester, {
  FakeQuizService? quizService,
  bool withChild = true,
  bool settle = true,
}) async {
  final harness = _Harness(
    quizService ?? FakeQuizService(),
    _FakeRewardService(),
    FakeFlutterTts(),
  );

  final activeChild = ActiveChildProvider(profileService: const _StubProfileService());
  if (withChild) {
    activeChild.setActiveChild(const ChildProfile(childProfileId: 3, childName: '첫째'));
  }
  // 첫 갱신은 비교 기준(레벨 1)을 잡는 용도라 레벨업으로 보지 않는다.
  final rewardProvider = RewardProvider(rewardService: harness.rewardService);
  await rewardProvider.refresh(3);
  harness.rewardService.refreshCalls = 0;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<RewardProvider>.value(value: rewardProvider),
        Provider<QuizService>.value(value: harness.quizService),
        Provider<TtsService>.value(value: TtsService(flutterTts: harness.tts)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  harness.poppedWith = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(builder: (_) => const QuizScreen(storyId: 11)),
                  );
                  harness.popped = true;
                },
                child: const Text('퀴즈 열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('퀴즈 열기'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 화면 전환 애니메이션이 진행되도록 두 프레임을 그린다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return harness;
}

Future<void> _answerAll(
  WidgetTester tester, {
  String first = 'Candy Forest',
  String second = 'A little bird',
}) async {
  await tester.tap(find.text(first));
  await tester.pump();
  await tester.tap(find.text('다음 →'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(second));
  await tester.pump();
}

Future<void> _finishCelebration(WidgetTester tester) async {
  // 축하 연출은 2.5초 뒤 저절로 닫힌다.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('불러오는 동안 안내를 보여주고, 끝나면 첫 문항과 진행률을 보여준다', (tester) async {
    final service = FakeQuizService()..generateGate = Completer<void>();
    // 로딩 스피너는 계속 돌아서 pumpAndSettle이 끝나지 않으므로 한 프레임만 그린다.
    await _pumpQuiz(tester, quizService: service, settle: false);
    expect(find.text('마법사가 퀴즈를 만들고 있어요...'), findsOneWidget);
    expect(find.text('Where did the bunny go?'), findsNothing);

    service.generateGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('마법사가 퀴즈를 만들고 있어요...'), findsNothing);
    expect(find.text('Q1 / 2'), findsOneWidget);
    expect(find.text('Where did the bunny go?'), findsOneWidget);
    expect(find.text('동화 내용 확인'), findsOneWidget);
    expect(find.text('Candy Forest'), findsOneWidget);
    expect(find.text('Cookie Castle'), findsOneWidget);
    expect(find.text('퀴즈 건너뛰기'), findsOneWidget);
  });

  testWidgets('보기를 고르기 전에는 다음 버튼이 꺼져 있고, 문제 풀이 중에는 정답을 알려주지 않는다', (tester) async {
    await _pumpQuiz(tester);

    expect(
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '다음 →')).onPressed,
      isNull,
    );

    await tester.tap(find.text('Cookie Castle'));
    await tester.pump();

    expect(
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '다음 →')).onPressed,
      isNotNull,
    );
    expect(find.text('정답'), findsNothing);
  });

  testWidgets('발음 듣기는 문제를 읽어 준다', (tester) async {
    final harness = await _pumpQuiz(tester);

    await tester.tap(find.text('발음 듣기'));
    await tester.pump();

    expect(harness.tts.spokenWords, ['Where did the bunny go?']);
  });

  testWidgets('마지막 문항에서 모두 답하면 제출하고 문항별 정답을 보여준다', (tester) async {
    final harness = await _pumpQuiz(tester);
    harness.quizService.pointsEarned = 5;

    await _answerAll(tester, second: 'A big bear'); // 1번 정답, 2번 오답
    expect(find.text('제출하기'), findsOneWidget);
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();

    expect(harness.quizService.submitCalls, 1);
    expect(harness.quizService.lastAnswers, {101: 1001, 102: 1004});
    expect(find.text('퀴즈 결과'), findsOneWidget);
    expect(find.text('2문제 중 1문제 맞혔어요!'), findsOneWidget);
    expect(find.text('마법 토큰 +5'), findsOneWidget);
    expect(find.text('정답'), findsNWidgets(2)); // 문항마다 정답 표시
    expect(find.text('내가 고른 답'), findsOneWidget); // 틀린 문항에만
    expect(find.text('제출하기'), findsNothing);
    // 메인 화면 토큰 표시를 갱신하려고 보상 정보를 다시 읽는다.
    expect(harness.rewardService.refreshCalls, 1);

    await _finishCelebration(tester);
  });

  testWidgets('포인트를 받으면 축하 연출을 띄우고, 레벨이 오르면 새 레벨도 알려 준다', (tester) async {
    final harness = await _pumpQuiz(tester);
    harness.rewardService.level = 2;

    await _answerAll(tester);
    await tester.tap(find.text('제출하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RewardCelebration), findsOneWidget);
    expect(find.text('레벨 업! Lv.2'), findsOneWidget);

    await _finishCelebration(tester);
    expect(find.byType(RewardCelebration), findsNothing);
  });

  testWidgets('받은 포인트가 없으면 축하 연출 없이 결과만 보여준다', (tester) async {
    final harness = await _pumpQuiz(tester);
    harness.quizService.pointsEarned = 0;

    await _answerAll(tester, first: 'Cookie Castle', second: 'A big bear'); // 모두 오답
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();

    expect(find.text('2문제 중 0문제 맞혔어요!'), findsOneWidget);
    expect(find.byType(RewardCelebration), findsNothing);
    expect(find.textContaining('마법 토큰 +'), findsNothing);
  });

  testWidgets('제출에 실패하면 오류를 보여주고 답안을 유지한 채 다시 제출할 수 있다', (tester) async {
    final harness = await _pumpQuiz(tester);
    harness.quizService.submitError = const ApiException(message: '서버에 연결할 수 없어요.');

    await _answerAll(tester);
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.text('퀴즈 결과'), findsNothing);

    harness.quizService.submitError = null;
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();

    expect(find.text('퀴즈 결과'), findsOneWidget);
    expect(harness.quizService.submitCalls, 2);
    await _finishCelebration(tester);
  });

  testWidgets('제출 중에는 뒤로 가도 화면이 닫히지 않고 버튼이 다시 눌리지 않는다', (tester) async {
    final harness = await _pumpQuiz(tester);
    final gate = harness.quizService.submitGate = Completer<void>();

    await _answerAll(tester);
    await tester.tap(find.text('제출하기'));
    await tester.pump();

    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump();
    expect(harness.popped, isFalse);
    expect(find.text('동화 확인 퀴즈'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(harness.quizService.submitCalls, 1);
    await _finishCelebration(tester);
  });

  testWidgets('결과에서 완료를 누르면 채점을 마쳤다는 뜻으로 true를 돌려주고 닫힌다', (tester) async {
    final harness = await _pumpQuiz(tester);

    await _answerAll(tester);
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();
    await _finishCelebration(tester);
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(harness.popped, isTrue);
    expect(harness.poppedWith, isTrue);
  });

  testWidgets('채점 뒤 시스템 뒤로가기로 나가도 true를 돌려준다 (재응시 방지)', (tester) async {
    final harness = await _pumpQuiz(tester);

    await _answerAll(tester);
    await tester.tap(find.text('제출하기'));
    await tester.pumpAndSettle();
    await _finishCelebration(tester);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();

    expect(harness.poppedWith, isTrue);
  });

  testWidgets('퀴즈 건너뛰기를 누르면 제출 없이 false를 돌려주고 닫힌다', (tester) async {
    final harness = await _pumpQuiz(tester);

    await tester.tap(find.text('퀴즈 건너뛰기'));
    await tester.pumpAndSettle();

    expect(harness.popped, isTrue);
    expect(harness.poppedWith, isFalse);
    expect(harness.quizService.submitCalls, 0);
  });

  testWidgets('생성에 실패하면 오류와 다시 시도 버튼을 보여주고, 다시 시도하면 문항이 나온다', (tester) async {
    final service = FakeQuizService()
      ..generateError = const ApiException(message: '퀴즈 생성에 실패했습니다. 다시 시도해주세요.', statusCode: 502);
    await _pumpQuiz(tester, quizService: service);

    expect(find.text('퀴즈 생성에 실패했습니다. 다시 시도해주세요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);

    service.generateError = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('Q1 / 2'), findsOneWidget);
  });

  testWidgets('문항이 하나도 없으면 준비 안내를 보여준다', (tester) async {
    final service = FakeQuizService()..questions = const [];
    await _pumpQuiz(tester, quizService: service);

    expect(find.textContaining('퀴즈가 아직 준비되지 않았어요'), findsOneWidget);
  });

  testWidgets('자녀가 선택되지 않았으면 안내 문구를 보여주고 퀴즈를 만들지 않는다', (tester) async {
    final service = FakeQuizService();
    await _pumpQuiz(tester, quizService: service, withChild: false);

    expect(find.text('먼저 자녀 프로필을 선택해 주세요.'), findsOneWidget);
    expect(service.generateCalls, 0);
  });
}
