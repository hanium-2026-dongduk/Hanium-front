import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/story.dart';
import '../models/story_payload.dart';
import '../services/story_service.dart';

/// 동화 결과 화면 전용. (P-SG04 생성 결과, P-LB03 상세 보기)
///
/// **화면 단위 Provider다.** `StoryResultScreen`이 열릴 때마다 새로 만든다.
/// [payload]가 있으면 새로 만들고(`POST /stories`), [storyId]만 있으면
/// 이미 저장된 동화를 그대로 불러온다(`GET /stories/:id`) — 라이브러리에서
/// "열기"로 들어온 경우다.
class StoryResultProvider extends ChangeNotifier {
  final StoryService _storyService;
  final int childProfileId;
  final StoryCreatePayload? payload;
  final int? initialStoryId;

  /// 자녀 나이. 서버 프롬프트의 난이도·어휘 수준에 반영되므로 생성 모드에서는
  /// 반드시 자녀 프로필에서 읽어와 넘겨야 한다(`ActiveChildProvider.activeChild?.age`).
  final int? childAge;

  StoryResultProvider({
    required StoryService storyService,
    required this.childProfileId,
    this.payload,
    this.initialStoryId,
    this.childAge,
    bool initialIsFavorite = false,
  }) : _storyService = storyService,
       _isFavorite = initialIsFavorite,
       assert(
         payload != null || initialStoryId != null,
         'payload(생성) 또는 storyId(조회) 중 하나는 있어야 한다',
       );

  StoryDetail? _story;
  int? _storyId;

  // 화면이 열리자마자 생성/조회를 시작하므로 첫 프레임부터 로딩으로 시작한다.
  bool _isLoading = true;
  bool _loadInProgress = false;
  String? _loadError;
  bool _isFavorite;
  bool _isTogglingFavorite = false;
  String? _favoriteError;
  bool _disposed = false;

  StoryDetail? get story => _story;
  int? get storyId => _storyId;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isFavorite => _isFavorite;
  bool get isTogglingFavorite => _isTogglingFavorite;
  String? get favoriteError => _favoriteError;

  /// 저장된 다음 이야기 선택지. 분기 API는 없어 읽기 전용으로 보여준다.
  List<String> get choices => _story?.choices ?? const [];

  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    _isLoading = true;
    _loadError = null;
    _safeNotify();

    try {
      final id = initialStoryId;
      if (id != null) {
        _story = await _storyService.fetchStory(
          childProfileId: childProfileId,
          storyId: id,
        );
        _storyId = id;
      } else {
        final p = payload!;
        final characterId = p.characterId;
        if (characterId == null) {
          _loadError = '캐릭터 정보가 없어요. 이전 단계로 돌아가 다시 시도해 주세요.';
          return;
        }
        final created = await _storyService.createStory(
          childProfileId: childProfileId,
          characterId: characterId,
          background: p.location ?? '',
          mainEvent: p.event ?? '',
          childAge: childAge,
          imageStyle: p.imageStyle,
          keyword: p.keyword,
          requestId: p.generationRequestIdFor(
            childProfileId: childProfileId,
            characterId: characterId,
            background: p.location ?? '',
            mainEvent: p.event ?? '',
            childAge: childAge,
            imageStyle: p.imageStyle,
            keyword: p.keyword,
          ),
        );
        _story = created;
        _storyId = created.storyId;
      }
    } on StoryGenerationFailedException catch (error) {
      payload?.resetGenerationRequest();
      _loadError = error.message;
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _loadInProgress = false;
      _isLoading = false;
      _safeNotify();
    }
  }

  /// 즐겨찾기를 켜거나 끈다. 실패하면 상태를 되돌리고 [favoriteError]에 메시지를 남긴다.
  Future<void> toggleFavorite() async {
    final id = _storyId;
    if (id == null || _isTogglingFavorite) return;

    _isTogglingFavorite = true;
    _favoriteError = null;
    _safeNotify();

    final next = !_isFavorite;
    try {
      if (next) {
        await _storyService.addFavorite(
          childProfileId: childProfileId,
          storyId: id,
        );
      } else {
        await _storyService.removeFavorite(
          childProfileId: childProfileId,
          storyId: id,
        );
      }
      _isFavorite = next;
    } on ApiException catch (error) {
      _favoriteError = error.message;
    } finally {
      _isTogglingFavorite = false;
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
