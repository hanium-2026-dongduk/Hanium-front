import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/story.dart';
import '../services/story_service.dart';

/// 라이브러리 목록 화면 전용. (P-LB01~05)
///
/// **화면 단위 Provider다.** `LibraryScreen`이 열릴 때마다 새로 만든다.
/// 제목 검색은 서버 API가 없어 화면이 [stories]를 그대로 받아 클라이언트에서
/// 거른다. 정렬·즐겨찾기 필터는 서버 파라미터라 값이 바뀌면 다시 불러온다.
class LibraryProvider extends ChangeNotifier {
  final StoryService _storyService;
  final int childProfileId;

  LibraryProvider({
    required StoryService storyService,
    required this.childProfileId,
  }) : _storyService = storyService;

  List<StorySummary> _stories = const [];

  // 화면이 열리자마자 불러오므로 첫 프레임부터 로딩으로 시작한다.
  bool _isLoading = true;
  String? _loadError;
  String _sortOption = 'latest';
  bool _showOnlyFavorites = false;
  final Set<int> _pendingFavoriteToggles = {};
  final Set<int> _pendingDeletes = {};
  bool _disposed = false;

  List<StorySummary> get stories => _stories;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isEmpty => !_isLoading && _loadError == null && _stories.isEmpty;
  String get sortOption => _sortOption;
  bool get showOnlyFavorites => _showOnlyFavorites;

  /// GET /api/stories. `favoriteOnly`가 false면 `favorite` 쿼리를 아예 보내지
  /// 않는다(`StoryService` 참고 — `favorite=false`도 참으로 읽힌다).
  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _safeNotify();

    try {
      final result = await _storyService.fetchStories(
        childProfileId: childProfileId,
        sort: _sortOption,
        favoriteOnly: _showOnlyFavorites,
      );
      _stories = result.items;
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> setSortOption(String option) {
    if (_sortOption == option) return Future.value();
    _sortOption = option;
    return load();
  }

  Future<void> setShowOnlyFavorites(bool value) {
    if (_showOnlyFavorites == value) return Future.value();
    _showOnlyFavorites = value;
    return load();
  }

  bool isTogglingFavorite(int storyId) =>
      _pendingFavoriteToggles.contains(storyId);
  bool isDeleting(int storyId) => _pendingDeletes.contains(storyId);

  /// 즐겨찾기를 켜거나 끈다. 실패하면 목록을 바꾸지 않고 false를 돌려준다.
  Future<bool> toggleFavorite(StorySummary story) async {
    final storyId = story.storyId;
    if (_pendingFavoriteToggles.contains(storyId)) return false;

    _pendingFavoriteToggles.add(storyId);
    _safeNotify();

    try {
      if (story.isFavorite) {
        await _storyService.removeFavorite(
          childProfileId: childProfileId,
          storyId: storyId,
        );
      } else {
        await _storyService.addFavorite(
          childProfileId: childProfileId,
          storyId: storyId,
        );
      }
      final index = _stories.indexWhere((s) => s.storyId == storyId);
      if (index != -1) {
        final updated = StorySummary(
          storyId: storyId,
          title: story.title,
          isFavorite: !story.isFavorite,
          createdAt: story.createdAt,
        );
        final next = List<StorySummary>.of(_stories);
        // 즐겨찾기만 보기 상태에서 해제하면 목록에서도 사라져야 한다.
        if (_showOnlyFavorites && story.isFavorite) {
          next.removeAt(index);
        } else {
          next[index] = updated;
        }
        _stories = next;
      }
      return true;
    } on ApiException {
      return false;
    } finally {
      _pendingFavoriteToggles.remove(storyId);
      _safeNotify();
    }
  }

  /// 동화를 삭제한다. 실패하면 목록을 바꾸지 않고 false를 돌려준다.
  Future<bool> deleteStory(int storyId) async {
    if (_pendingDeletes.contains(storyId)) return false;

    _pendingDeletes.add(storyId);
    _safeNotify();

    try {
      await _storyService.deleteStory(
        childProfileId: childProfileId,
        storyId: storyId,
      );
      _stories = _stories.where((s) => s.storyId != storyId).toList();
      return true;
    } on ApiException {
      return false;
    } finally {
      _pendingDeletes.remove(storyId);
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
