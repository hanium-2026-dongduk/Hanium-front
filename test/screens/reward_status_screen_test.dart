import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/badge_status.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/reward_status_provider.dart';
import 'package:hanium_front/screens/mypage/reward_status_screen.dart';
import 'package:hanium_front/services/badge_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:provider/provider.dart';

class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardService implements RewardService {
  ApiException? error;
  RewardDetail detail = const RewardDetail(
    childProfileId: 1,
    points: 340,
    level: 3,
    streakDays: 4,
    levelProgress: LevelProgress(currentLevelFloor: 300, nextLevelAt: 600, pointsToNextLevel: 260),
  );

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) async {
    if (error != null) throw error!;
    return detail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBadgeService implements BadgeService {
  BadgeSummary summary = const BadgeSummary(
    earnedCount: 1,
    totalCount: 2,
    badges: [
      BadgeStatus(
        badgeCode: 'streak_10',
        name: '불꽃 출석왕',
        description: '10일 연속 출석',
        iconKey: 'fire',
        condition: BadgeCondition(type: 'streak_days', value: 10),
        state: BadgeState.earned,
      ),
      BadgeStatus(
        badgeCode: 'story_10',
        name: '동화 박사',
        description: '동화 10편 읽기',
        iconKey: 'book',
        condition: BadgeCondition(type: 'story_read_total', value: 10),
        state: BadgeState.locked,
      ),
    ],
  );

  @override
  Future<BadgeSummary> fetchChildBadges(int childProfileId) async => summary;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeRewardService rewardService,
  required _FakeBadgeService badgeService,
  bool withChild = true,
}) async {
  final activeChild = ActiveChildProvider(profileService: const _StubProfileService());
  if (withChild) {
    activeChild.setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<RewardStatusProvider>(
          create: (_) =>
              RewardStatusProvider(rewardService: rewardService, badgeService: badgeService),
        ),
      ],
      child: const MaterialApp(home: RewardStatusScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('자녀를 바꾼 직후 첫 프레임에는 이전 자녀의 값을 보여주지 않는다', (tester) async {
    final rewardService = _FakeRewardService();
    final provider = RewardStatusProvider(
      rewardService: rewardService,
      badgeService: _FakeBadgeService(),
    );
    await provider.load(1); // 첫째 화면을 봤던 상태로 Provider에 값이 남아 있다.

    final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
      ..setActiveChild(const ChildProfile(childProfileId: 2, childName: '둘째'));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          ChangeNotifierProvider<RewardStatusProvider>.value(value: provider),
        ],
        child: const MaterialApp(home: RewardStatusScreen()),
      ),
    );

    // 첫 프레임: 다음 프레임에 불러오기가 시작되기 전이므로 로딩만 보여야 한다.
    expect(find.text('340'), findsNothing);
    expect(find.text('불꽃 출석왕'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('340'), findsOneWidget);
  });

  testWidgets('레벨·포인트·진행 안내와 배지를 보여준다', (tester) async {
    await _pumpScreen(
      tester,
      rewardService: _FakeRewardService(),
      badgeService: _FakeBadgeService(),
    );

    expect(find.text('Lv.3'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('다음 레벨까지 마법 토큰 260개 남았어요'), findsOneWidget);
    expect(find.text('내 배지 1/2'), findsOneWidget);
    expect(find.text('불꽃 출석왕'), findsOneWidget);
    expect(find.text('동화 박사'), findsOneWidget);
    expect(find.text('보상 내역 보기'), findsOneWidget);
  });

  testWidgets('좁은 화면·큰 글씨에서도 배지 이름이 두 줄이어도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final badgeService = _FakeBadgeService()
      ..summary = const BadgeSummary(
        earnedCount: 1,
        totalCount: 3,
        badges: [
          BadgeStatus(
            badgeCode: 'a',
            name: '아주 긴 이름의 출석 배지',
            description: '설명',
            iconKey: 'fire',
            condition: BadgeCondition(type: 'streak_days', value: 10),
            state: BadgeState.earned,
          ),
          BadgeStatus(
            badgeCode: 'b',
            name: '아주 긴 이름의 동화 배지',
            description: '설명',
            iconKey: 'book',
            condition: BadgeCondition(type: 'story_read_total', value: 10),
            state: BadgeState.locked,
          ),
          BadgeStatus(
            badgeCode: 'c',
            name: '아주 긴 이름의 퀴즈 배지',
            description: '설명',
            iconKey: 'star',
            condition: BadgeCondition(type: 'quiz_count', value: 5),
            state: BadgeState.locked,
          ),
        ],
      );
    await _pumpScreen(tester, rewardService: _FakeRewardService(), badgeService: badgeService);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('아주 긴 이름의 출석 배지'), findsOneWidget);
    expect(tester.takeException(), isNull); // RenderFlex overflow가 없어야 한다.
  });

  testWidgets('최고 레벨이면 다음 레벨 안내 대신 축하 문구를 보여준다', (tester) async {
    final rewardService = _FakeRewardService()
      ..detail = const RewardDetail(
        childProfileId: 1,
        points: 6000,
        level: 10,
        streakDays: 30,
        levelProgress: LevelProgress(currentLevelFloor: 5200),
      );
    await _pumpScreen(tester, rewardService: rewardService, badgeService: _FakeBadgeService());

    expect(find.text('Lv.10'), findsOneWidget);
    expect(find.text('최고 레벨이에요! 🎉'), findsOneWidget);
  });

  testWidgets('잠긴 배지를 누르면 획득 방법을 안내한다', (tester) async {
    await _pumpScreen(
      tester,
      rewardService: _FakeRewardService(),
      badgeService: _FakeBadgeService(),
    );

    await tester.tap(find.text('동화 박사'));
    await tester.pumpAndSettle();

    expect(find.text('동화를 10편 읽으면 받을 수 있어요'), findsOneWidget);
  });

  testWidgets('배지가 하나도 없으면 빈 안내를 보여준다', (tester) async {
    final badgeService = _FakeBadgeService()
      ..summary = const BadgeSummary(badges: [], earnedCount: 0, totalCount: 0);
    await _pumpScreen(tester, rewardService: _FakeRewardService(), badgeService: badgeService);

    expect(find.text('아직 배지가 없어요.'), findsOneWidget);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final rewardService = _FakeRewardService()
      ..error = const ApiException(message: '서버에 연결할 수 없어요.');
    await _pumpScreen(tester, rewardService: rewardService, badgeService: _FakeBadgeService());

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('자녀가 선택되지 않았으면 안내 문구를 보여준다', (tester) async {
    await _pumpScreen(
      tester,
      rewardService: _FakeRewardService(),
      badgeService: _FakeBadgeService(),
      withChild: false,
    );

    expect(find.text('먼저 자녀 프로필을 선택해 주세요.'), findsOneWidget);
  });
}
