import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/dashboard_summary.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/main_screen.dart';
import 'package:hanium_front/screens/story_creation_screen.dart';
import 'package:hanium_front/services/character_service.dart';
import 'package:hanium_front/services/dashboard_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_character_service.dart';

/// 메인 화면의 집계와 주요 이동 경로를 확인한다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardService implements RewardService {
  @override
  Future<RewardDetail> fetchDetail(int childProfileId) async => RewardDetail(
    childProfileId: childProfileId,
    points: 0,
    level: 1,
    streakDays: 0,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDashboardService implements DashboardService {
  int calls = 0;
  ApiException? error;

  @override
  Future<DashboardSummary> fetchSummary(int childProfileId) async {
    calls++;
    if (error != null) throw error!;
    return DashboardSummary(
      storyCount: childProfileId,
      favoriteStoryCount: 1,
      vocabularyCount: 5,
      quizStats: const QuizStats(totalAttempts: 2, averageScore: 80),
    );
  }
}

Future<({ActiveChildProvider activeChild, _FakeDashboardService dashboard})>
_pumpMain(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  ApiException? dashboardError,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final activeChild = ActiveChildProvider(
    profileService: const _StubProfileService(),
  )..setActiveChild(const ChildProfile(childProfileId: 3, childName: '첫째'));
  final dashboardService = _FakeDashboardService();
  dashboardService.error = dashboardError;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<RewardProvider>(
          create: (_) => RewardProvider(rewardService: _FakeRewardService()),
        ),
        Provider<CharacterService>.value(value: FakeCharacterService()),
        Provider<DashboardService>.value(value: dashboardService),
      ],
      child: const MaterialApp(home: MainScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (activeChild: activeChild, dashboard: dashboardService);
}

void main() {
  testWidgets('대시보드 집계를 표시하고 생성 화면에서 돌아오면 새로고침한다', (tester) async {
    final state = await _pumpMain(tester);

    expect(find.text('3권'), findsOneWidget);
    expect(find.text('5개'), findsOneWidget);
    expect(find.text('2회'), findsOneWidget);
    expect(state.dashboard.calls, 1);

    await tester.tap(find.text('동화\n생성하기'));
    await tester.pumpAndSettle();

    expect(find.byType(StoryCreationScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.dashboard.calls, 2);
  });

  testWidgets('자녀가 바뀌면 메인 화면도 새 자녀의 집계를 보여준다', (tester) async {
    final state = await _pumpMain(tester, size: const Size(390, 844));

    state.activeChild.setActiveChild(
      const ChildProfile(childProfileId: 4, childName: '둘째'),
    );
    await tester.pumpAndSettle();

    expect(state.dashboard.calls, 2);
    expect(find.text('4권'), findsOneWidget);
    expect(find.text('3권'), findsNothing);
  });

  testWidgets('집계 조회 실패 시 재시도 버튼으로 다시 불러온다', (tester) async {
    final state = await _pumpMain(
      tester,
      dashboardError: const ApiException(message: '네트워크 오류'),
    );

    expect(find.text('학습 현황을 불러오지 못했어요. 다시 시도'), findsOneWidget);
    state.dashboard.error = null;
    await tester.tap(find.text('학습 현황을 불러오지 못했어요. 다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('3권'), findsOneWidget);
    expect(state.dashboard.calls, 2);
  });
}
