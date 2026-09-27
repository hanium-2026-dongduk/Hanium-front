import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/main_screen.dart';
import 'package:hanium_front/screens/story_creation_screen.dart';
import 'package:hanium_front/services/character_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_character_service.dart';

/// 메인 화면 '동화 생성하기' 카드가 SG01로 이어지는지만 본다.
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

void main() {
  testWidgets('동화 생성하기 카드를 누르면 StoryCreationScreen이 열린다', (tester) async {
    // '학습하기'와 텍스트가 겹치지 않도록, 그리고 스크롤 없이 카드가 보이도록 넉넉히 그린다.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final activeChild = ActiveChildProvider(
      profileService: const _StubProfileService(),
    )..setActiveChild(const ChildProfile(childProfileId: 3, childName: '첫째'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          ChangeNotifierProvider<RewardProvider>(
            create: (_) => RewardProvider(rewardService: _FakeRewardService()),
          ),
          Provider<CharacterService>.value(value: FakeCharacterService()),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('동화\n생성하기'));
    await tester.pumpAndSettle();

    expect(find.byType(StoryCreationScreen), findsOneWidget);
  });
}
