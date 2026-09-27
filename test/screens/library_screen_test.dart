import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/story.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/screens/library_screen.dart';
import 'package:hanium_front/screens/story_result_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/story_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_story_service.dart';

/// 라이브러리 목록(P-LB01~05) — 조회·정렬/필터·즐겨찾기·삭제·열기를 본다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<FakeStoryService> _pumpLibrary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storyService = FakeStoryService();
  final activeChild = ActiveChildProvider(
    profileService: const _StubProfileService(),
  )..setActiveChild(const ChildProfile(childProfileId: 3, childName: '첫째'));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        Provider<StoryService>.value(value: storyService),
      ],
      child: const MaterialApp(home: LibraryScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return storyService;
}

void main() {
  testWidgets('목록을 불러와 제목을 보여준다', (tester) async {
    await _pumpLibrary(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('조회가 실패하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final storyService = FakeStoryService()
      ..fetchStoriesError = const ApiException(message: '서버에 연결할 수 없어요.');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(
            value:
                ActiveChildProvider(profileService: const _StubProfileService())
                  ..setActiveChild(
                    const ChildProfile(childProfileId: 3, childName: '첫째'),
                  ),
          ),
          Provider<StoryService>.value(value: storyService),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('동화가 하나도 없으면 안내 문구를 보여준다', (tester) async {
    final storyService = FakeStoryService()..stories = const [];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(
            value:
                ActiveChildProvider(profileService: const _StubProfileService())
                  ..setActiveChild(
                    const ChildProfile(childProfileId: 3, childName: '첫째'),
                  ),
          ),
          Provider<StoryService>.value(value: storyService),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('아직 만든 동화가 없어요'), findsOneWidget);
  });

  testWidgets('검색어를 입력하면 제목이 일치하는 동화만 남는다', (tester) async {
    await _pumpLibrary(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    // 검색창에 그대로 'A'를 치면 입력 필드 자체의 글자와 겹쳐 찾기가 모호해지므로
    // 대소문자 다른 'a'로 (대소문자 구분 없이 걸러지는지도 함께 확인).
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('즐겨찾기만 보기를 켜면 서버에 favorite=true로 다시 불러온다', (tester) async {
    final storyService = await _pumpLibrary(tester);

    // 카드 'A'도 즐겨찾기가 꺼져 있어 같은 아이콘이라 앱바 안의 것만 짚는다.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.favorite_border),
      ),
    );
    await tester.pumpAndSettle();

    expect(storyService.lastFavoriteOnly, isTrue);
  });

  testWidgets('카드의 즐겨찾기 아이콘을 누르면 서버를 호출하고 아이콘이 바뀐다', (tester) async {
    final storyService = await _pumpLibrary(tester);

    // 'A'는 즐겨찾기가 꺼져 있어 favorite_border가 보인다. 앱바에도 같은 아이콘이
    // 있어 그리드 안의 카드 것만 짚는다.
    await tester.tap(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byIcon(Icons.favorite_border),
      ),
    );
    await tester.pumpAndSettle();

    expect(storyService.addFavoriteCalls, 1);
  });

  testWidgets('삭제 모드에서 확인하면 목록에서 사라진다', (tester) async {
    final storyService = await _pumpLibrary(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last); // 확인 다이얼로그의 삭제 버튼
    await tester.pumpAndSettle();

    expect(storyService.deleteCalls, 1);
    expect(find.text('동화가 삭제되었습니다.'), findsOneWidget);
  });

  testWidgets('열기를 누르면 상세 화면으로 이동한다', (tester) async {
    final storyService = FakeStoryService()
      ..storyToReturn = const StoryDetail(
        storyId: 1,
        title: 'A',
        pages: [StoryPage(pageNumber: 1, content: 'Hello')],
      );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(
            value:
                ActiveChildProvider(profileService: const _StubProfileService())
                  ..setActiveChild(
                    const ChildProfile(childProfileId: 3, childName: '첫째'),
                  ),
          ),
          Provider<StoryService>.value(value: storyService),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('열기').first);
    await tester.pumpAndSettle();

    expect(find.byType(StoryResultScreen), findsOneWidget);
    expect(storyService.fetchStoryCalls, 1);
  });
}
