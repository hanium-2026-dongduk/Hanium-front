import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/models/reward_history_entry.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/auth/profile_list_screen.dart';
import 'package:hanium_front/screens/main_screen.dart';
import 'package:hanium_front/screens/settings/account_security_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 프로필을 고르면 메인 화면으로 넘어가므로, 그 화면이 요구하는 Provider들도
/// 최소한으로 채워둔다. (ActiveChildProvider, RewardProvider)
class _FakeRewardService implements RewardService {
  @override
  Future<int> fetchPointBalance(int childProfileId) async => 0;

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) =>
      throw UnimplementedError();

  @override
  Future<PageResult<RewardHistoryEntry>> fetchHistory(
    int childProfileId, {
    int page = 1,
    int limit = 20,
    String? reason,
  }) => throw UnimplementedError();
}

/// 자녀 프로필 화면(P-AU-AU04)이 목록·활성 전환·삭제를 제대로 다루는지 본다.
/// 통신은 하지 않고 ProfileService 대신 가짜를 끼운다.
class _FakeProfileService implements ProfileService {
  _FakeProfileService(this._profiles);

  List<ChildProfile> _profiles;

  ApiException? fetchError;
  final List<int> activatedIds = [];
  final List<int> deletedIds = [];
  final List<ChildProfile> created = [];
  final List<ChildProfile> updated = [];

  @override
  Future<List<ChildProfile>> fetchProfiles() async {
    if (fetchError != null) throw fetchError!;
    return _profiles;
  }

  @override
  Future<ChildProfile> activateProfile(int childProfileId) async {
    activatedIds.add(childProfileId);
    // 서버처럼 활성은 하나만 남긴다.
    _profiles = _profiles
        .map(
          (p) => ChildProfile(
            childProfileId: p.childProfileId,
            childName: p.childName,
            age: p.age,
            learningLevel: p.learningLevel,
            isActive: p.childProfileId == childProfileId,
          ),
        )
        .toList();
    return _profiles.firstWhere((p) => p.childProfileId == childProfileId);
  }

  @override
  Future<void> deleteProfile(int childProfileId) async {
    deletedIds.add(childProfileId);
    _profiles = _profiles
        .where((p) => p.childProfileId != childProfileId)
        .toList();
  }

  @override
  Future<ChildProfile> createProfile(ChildProfile draft) async {
    created.add(draft);
    return draft;
  }

  @override
  Future<ChildProfile> updateProfile(ChildProfile profile) async {
    updated.add(profile);
    return profile;
  }
}

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

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeProfileService service,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<ProfileService>.value(value: service),
          // 프로필을 고르면 MainScreen으로 넘어가는데, 그 화면이 읽는
          // Provider들이다. 실제로 쓰이지는 않아도 없으면 화면 생성이 죽는다.
          ChangeNotifierProvider<ActiveChildProvider>(
            create: (_) => ActiveChildProvider(profileService: service),
          ),
          ChangeNotifierProvider<RewardProvider>(
            create: (_) => RewardProvider(rewardService: _FakeRewardService()),
          ),
        ],
        child: const MaterialApp(home: ProfileListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('프로필이 없으면 안내 문구를 보여준다', (tester) async {
    await pumpScreen(tester, _FakeProfileService([]));

    expect(find.textContaining('아직 등록된 자녀 프로필이 없어요'), findsOneWidget);
  });

  testWidgets('목록을 이름·나이·학습 수준과 함께 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeProfileService([
        const ChildProfile(
          childProfileId: 1,
          childName: '첫째',
          age: 7,
          learningLevel: LearningLevel.intermediate,
          isActive: true,
        ),
      ]),
    );

    expect(find.text('첫째'), findsOneWidget);
    expect(find.text('7살 · 중급'), findsOneWidget);
  });

  testWidgets('나이가 없으면 학습 수준만 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeProfileService([
        const ChildProfile(childProfileId: 1, childName: '첫째'),
      ]),
    );

    expect(find.text('초급'), findsOneWidget);
  });

  testWidgets('활성 프로필에만 사용 중 배지를 붙인다', (tester) async {
    await pumpScreen(
      tester,
      _FakeProfileService([
        const ChildProfile(childProfileId: 1, childName: '첫째', isActive: true),
        const ChildProfile(childProfileId: 2, childName: '둘째'),
      ]),
    );

    expect(find.text('사용 중'), findsOneWidget);
  });

  testWidgets('비활성 프로필을 누르면 활성으로 전환하고 메인 화면으로 들어간다', (tester) async {
    final service = _FakeProfileService([
      const ChildProfile(childProfileId: 1, childName: '첫째', isActive: true),
      const ChildProfile(childProfileId: 2, childName: '둘째'),
    ]);
    await pumpScreen(tester, service);

    await tester.tap(find.text('둘째'));
    await tester.pumpAndSettle();

    expect(service.activatedIds, [2]);
    expect(find.byType(MainScreen), findsOneWidget);
  });

  testWidgets('이미 활성인 프로필을 눌러도 전환을 요청하지 않고 메인 화면으로 들어간다', (tester) async {
    final service = _FakeProfileService([
      const ChildProfile(childProfileId: 1, childName: '첫째', isActive: true),
    ]);
    await pumpScreen(tester, service);

    await tester.tap(find.text('첫째'));
    await tester.pumpAndSettle();

    expect(service.activatedIds, isEmpty);
    expect(find.byType(MainScreen), findsOneWidget);
  });

  testWidgets('삭제는 확인을 받고 나서 실행한다', (tester) async {
    final service = _FakeProfileService([
      const ChildProfile(childProfileId: 1, childName: '첫째'),
    ]);
    await pumpScreen(tester, service);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫째 프로필을 삭제할까요?'), findsOneWidget);

    // 취소하면 아무 일도 없어야 한다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(service.deletedIds, isEmpty);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();
    expect(service.deletedIds, [1]);
  });

  testWidgets('목록을 못 불러오면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final service = _FakeProfileService([])
      ..fetchError = const ApiException(message: '서버에 연결할 수 없어요.');
    await pumpScreen(tester, service);

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('서버에 이름이 없으므로 계정은 이메일로 표시한다', (tester) async {
    await pumpScreen(tester, _FakeProfileService([]));

    expect(find.text('parent@example.com'), findsOneWidget);
  });

  testWidgets('계정 보안 버튼을 누르면 계정 보안 화면으로 이동한다', (tester) async {
    await pumpScreen(tester, _FakeProfileService([]));

    await tester.tap(find.byTooltip('계정 보안'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountSecurityScreen), findsOneWidget);
  });

  testWidgets('추가 시트에서 입력한 값으로 프로필을 만든다', (tester) async {
    final service = _FakeProfileService([]);
    await pumpScreen(tester, service);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '셋째');
    await tester.enterText(find.byType(TextFormField).at(1), '9');
    await tester.tap(find.widgetWithText(ElevatedButton, '추가하기'));
    await tester.pumpAndSettle();

    expect(service.created.single.childName, '셋째');
    expect(service.created.single.age, 9);
  });

  testWidgets('나이가 서버 범위를 벗어나면 만들지 않는다', (tester) async {
    final service = _FakeProfileService([]);
    await pumpScreen(tester, service);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '셋째');
    await tester.enterText(find.byType(TextFormField).at(1), '20');
    await tester.tap(find.widgetWithText(ElevatedButton, '추가하기'));
    await tester.pumpAndSettle();

    expect(find.text('나이는 1살부터 15살까지 넣을 수 있어요.'), findsOneWidget);
    expect(service.created, isEmpty);
  });

  testWidgets('수정 시트는 기존 값을 채워두고 id를 유지한 채 저장한다', (tester) async {
    final service = _FakeProfileService([
      const ChildProfile(childProfileId: 7, childName: '첫째', age: 7),
    ]);
    await pumpScreen(tester, service);

    await tester.tap(find.byTooltip('수정'));
    await tester.pumpAndSettle();

    // 기존 값이 들어와 있어야 한다.
    expect(find.widgetWithText(TextFormField, '첫째'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '고친이름');
    await tester.tap(find.widgetWithText(ElevatedButton, '저장하기'));
    await tester.pumpAndSettle();

    expect(service.updated.single.childProfileId, 7);
    expect(service.updated.single.childName, '고친이름');
  });
}
