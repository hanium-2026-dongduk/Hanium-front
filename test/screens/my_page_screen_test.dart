import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/received_sticker.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/providers/received_sticker_provider.dart';
import 'package:hanium_front/screens/mypage/my_page_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/sticker_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyStickerService implements StickerService {
  @override
  Future<PageResult<ReceivedSticker>> fetchReceived(
    int childProfileId, {
    int page = 1,
    int limit = 20,
  }) async => const PageResult(items: [], page: 1, limit: 20, totalCount: 0, totalPages: 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpScreen(WidgetTester tester, {ChildProfile? child}) async {
  final activeChild = ActiveChildProvider(profileService: const _StubProfileService());
  if (child != null) activeChild.setActiveChild(child);
  final auth = FakeAuthProvider(
    status: AuthStatus.authenticated,
    user: const User(userId: 1, email: 'parent@example.com', role: 'parent', status: 'active'),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ReceivedStickerProvider>(
          create: (_) => ReceivedStickerProvider(stickerService: _EmptyStickerService()),
        ),
      ],
      child: const MaterialApp(home: MyPageScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('프로필 카드에 이름·나이·학습수준·보호자 이메일을 보여준다', (tester) async {
    await _pumpScreen(
      tester,
      child: const ChildProfile(
        childProfileId: 1,
        childName: '지우',
        age: 7,
        learningLevel: LearningLevel.intermediate,
      ),
    );

    expect(find.text('지우'), findsOneWidget);
    expect(find.text('7살 · 중급'), findsOneWidget);
    expect(find.text('보호자 parent@example.com'), findsOneWidget);
  });

  testWidgets('나이가 없으면 학습수준만 보여준다', (tester) async {
    await _pumpScreen(tester, child: const ChildProfile(childProfileId: 1, childName: '지우'));

    expect(find.text('초급'), findsOneWidget);
  });

  testWidgets('MP01은 표시 전용이라 수정 버튼이 없다', (tester) async {
    await _pumpScreen(tester, child: const ChildProfile(childProfileId: 1, childName: '지우'));

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.textContaining('수정'), findsNothing);
  });

  testWidgets('보상 현황·학습 통계·칭찬 스티커 메뉴를 순서대로 보여준다', (tester) async {
    await _pumpScreen(tester, child: const ChildProfile(childProfileId: 1, childName: '지우'));

    final rewardY = tester.getTopLeft(find.text('보상 현황')).dy;
    final statsY = tester.getTopLeft(find.text('학습 통계')).dy;
    final stickerY = tester.getTopLeft(find.text('칭찬 스티커')).dy;
    expect(rewardY, lessThan(statsY));
    expect(statsY, lessThan(stickerY));
  });

  testWidgets('칭찬 스티커 메뉴를 누르면 스티커 화면으로 이동한다', (tester) async {
    await _pumpScreen(tester, child: const ChildProfile(childProfileId: 1, childName: '지우'));

    await tester.tap(find.text('칭찬 스티커'));
    await tester.pumpAndSettle();

    expect(find.text('아직 받은 칭찬 스티커가 없어요'), findsOneWidget);
  });

  testWidgets('자녀가 선택되지 않았으면 안내 문구를 보여준다', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('먼저 자녀 프로필을 선택해 주세요.'), findsOneWidget);
    expect(find.text('보상 현황'), findsNothing);
  });
}
