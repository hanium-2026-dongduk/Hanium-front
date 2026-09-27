import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/providers/library_provider.dart';

import '../support/fake_story_service.dart';

void main() {
  late FakeStoryService service;
  late LibraryProvider provider;

  setUp(() {
    service = FakeStoryService();
    provider = LibraryProvider(storyService: service, childProfileId: 3);
  });

  tearDown(() => provider.dispose());

  test('만들자마자 로딩 상태이고, load가 끝나면 목록이 채워진다', () async {
    expect(provider.isLoading, isTrue);

    await provider.load();

    expect(provider.isLoading, isFalse);
    expect(provider.stories, hasLength(2));
    expect(service.lastFavoriteOnly, isFalse);
  });

  test('조회가 실패하면 오류 메시지를 남긴다', () async {
    service.fetchStoriesError = const ApiException(message: '서버에 연결할 수 없어요.');

    await provider.load();

    expect(provider.loadError, '서버에 연결할 수 없어요.');
    expect(provider.stories, isEmpty);
  });

  test('setSortOption은 값이 바뀔 때만 다시 불러온다', () async {
    await provider.load();
    expect(service.fetchStoriesCalls, 1);

    await provider.setSortOption('latest');
    expect(service.fetchStoriesCalls, 1); // 같은 값이면 다시 안 부른다

    await provider.setSortOption('oldest');
    expect(service.fetchStoriesCalls, 2);
    expect(service.lastSort, 'oldest');
  });

  test('setShowOnlyFavorites(true)는 favoriteOnly=true로 다시 불러온다', () async {
    await provider.load();

    await provider.setShowOnlyFavorites(true);

    expect(service.lastFavoriteOnly, isTrue);
  });

  test('toggleFavorite은 서버 호출 성공 후 목록의 해당 항목만 바꾼다', () async {
    await provider.load();

    final ok = await provider.toggleFavorite(provider.stories.first);

    expect(ok, isTrue);
    expect(provider.stories.first.isFavorite, isTrue);
    expect(service.addFavoriteCalls, 1);
  });

  test('즐겨찾기만 보기 상태에서 해제하면 목록에서 사라진다', () async {
    await provider.setShowOnlyFavorites(true);
    await provider.load();
    final favorite = provider.stories.firstWhere((s) => s.isFavorite);

    final ok = await provider.toggleFavorite(favorite);

    expect(ok, isTrue);
    expect(provider.stories.any((s) => s.storyId == favorite.storyId), isFalse);
  });

  test('toggleFavorite이 실패하면 목록을 바꾸지 않고 false를 돌려준다', () async {
    await provider.load();
    service.favoriteError = const ApiException(message: '실패');

    final ok = await provider.toggleFavorite(provider.stories.first);

    expect(ok, isFalse);
    expect(provider.stories.first.isFavorite, isFalse);
  });

  test('deleteStory는 성공하면 목록에서 제거하고 true를 돌려준다', () async {
    await provider.load();

    final ok = await provider.deleteStory(1);

    expect(ok, isTrue);
    expect(provider.stories.any((s) => s.storyId == 1), isFalse);
    expect(service.lastDeletedStoryId, 1);
  });

  test('deleteStory가 실패하면 목록을 바꾸지 않고 false를 돌려준다', () async {
    await provider.load();
    service.deleteError = const ApiException(message: '실패');

    final ok = await provider.deleteStory(1);

    expect(ok, isFalse);
    expect(provider.stories.any((s) => s.storyId == 1), isTrue);
  });
}
