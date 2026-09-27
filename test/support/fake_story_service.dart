import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/story.dart';
import 'package:hanium_front/services/story_service.dart';

/// 동화 Provider·화면 테스트용 가짜 StoryService.
class FakeStoryService implements StoryService {
  int createCalls = 0;
  int fetchStoriesCalls = 0;
  int fetchStoryCalls = 0;
  int deleteCalls = 0;
  int addFavoriteCalls = 0;
  int removeFavoriteCalls = 0;

  Map<String, dynamic>? lastCreateArgs;
  String? lastSort;
  bool? lastFavoriteOnly;
  int? lastDeletedStoryId;

  ApiException? createError;
  ApiException? fetchStoriesError;
  ApiException? fetchStoryError;
  ApiException? deleteError;
  ApiException? favoriteError;

  StoryDetail storyToReturn = const StoryDetail(
    storyId: 42,
    title: 'The Rabbit Adventure',
    pages: [
      StoryPage(
        pageNumber: 1,
        content: 'Once upon a time',
        imageUrl: '/images/1.png',
        audioUrl: '/audio/1.wav',
      ),
    ],
    characterName: '토끼',
    background: '신비로운 숲',
    mainEvent: '숨겨진 보물 찾기',
    choices: ['간다', '멈춘다'],
  );

  List<StorySummary> stories = const [
    StorySummary(storyId: 1, title: 'A', isFavorite: false),
    StorySummary(storyId: 2, title: 'B', isFavorite: true),
  ];

  @override
  Future<StoryDetail> createStory({
    required int childProfileId,
    required int characterId,
    required String background,
    required String mainEvent,
    int? childAge,
  }) async {
    createCalls++;
    lastCreateArgs = {
      'childProfileId': childProfileId,
      'characterId': characterId,
      'background': background,
      'mainEvent': mainEvent,
      'childAge': childAge,
    };
    if (createError != null) throw createError!;
    return storyToReturn;
  }

  @override
  Future<PageResult<StorySummary>> fetchStories({
    required int childProfileId,
    String sort = 'latest',
    bool favoriteOnly = false,
    int page = 1,
    int limit = 20,
  }) async {
    fetchStoriesCalls++;
    lastSort = sort;
    lastFavoriteOnly = favoriteOnly;
    if (fetchStoriesError != null) throw fetchStoriesError!;
    return PageResult(
      items: stories,
      page: page,
      limit: limit,
      totalCount: stories.length,
      totalPages: 1,
    );
  }

  @override
  Future<StoryDetail> fetchStory({
    required int childProfileId,
    required int storyId,
  }) async {
    fetchStoryCalls++;
    if (fetchStoryError != null) throw fetchStoryError!;
    return storyToReturn;
  }

  @override
  Future<void> deleteStory({
    required int childProfileId,
    required int storyId,
  }) async {
    deleteCalls++;
    lastDeletedStoryId = storyId;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<void> addFavorite({
    required int childProfileId,
    required int storyId,
  }) async {
    addFavoriteCalls++;
    if (favoriteError != null) throw favoriteError!;
  }

  @override
  Future<void> removeFavorite({
    required int childProfileId,
    required int storyId,
  }) async {
    removeFavoriteCalls++;
    if (favoriteError != null) throw favoriteError!;
  }
}
