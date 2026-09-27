import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/character.dart';
import '../services/character_service.dart';

/// 동화 생성 1단계(캐릭터 준비) 화면 전용. (P-SG01)
///
/// **화면 단위 Provider다.** `StoryCreationScreen`이 열릴 때마다 새로 만든다.
/// 목록 조회와 새 캐릭터 생성을 함께 다룬다.
class CharacterProvider extends ChangeNotifier {
  final CharacterService _characterService;

  CharacterProvider({required CharacterService characterService})
    : _characterService = characterService;

  List<Character> _characters = const [];

  // 화면이 열리자마자 목록을 불러오므로 첫 프레임부터 로딩으로 시작한다.
  bool _isLoading = true;
  String? _loadError;
  bool _isCreating = false;
  String? _createError;
  bool _disposed = false;

  List<Character> get characters => _characters;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isEmpty => !_isLoading && _loadError == null && _characters.isEmpty;
  bool get isCreating => _isCreating;
  String? get createError => _createError;

  /// GET /api/characters. 인증·소유권 구분이 없어 다른 사용자의 캐릭터도
  /// 함께 내려올 수 있다(back#40 3번, 백엔드 보완 요청함).
  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _safeNotify();

    try {
      _characters = await _characterService.fetchCharacters();
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// 새 캐릭터를 만들어 목록 맨 앞에 더한다. '직접 그리기'·'랜덤 생성'에서 쓴다.
  /// (그림 캔버스·이미지 업로드 API가 없어 텍스트 정보만 보낸다.)
  Future<Character?> create({
    required String name,
    required String personality,
    required String description,
    required String type,
  }) async {
    _isCreating = true;
    _createError = null;
    _safeNotify();

    try {
      final character = await _characterService.createCharacter(
        name: name,
        personality: personality,
        description: description,
        type: type,
      );
      _characters = [character, ..._characters];
      return character;
    } on ApiException catch (error) {
      _createError = error.message;
      return null;
    } finally {
      _isCreating = false;
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
