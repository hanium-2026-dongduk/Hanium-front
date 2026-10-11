import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/character.dart';
import 'package:hanium_front/services/character_service.dart';

/// 캐릭터 Provider·화면 테스트용 가짜 CharacterService.
class FakeCharacterService implements CharacterService {
  int fetchCalls = 0;
  int createCalls = 0;
  Character? lastCreated;

  /// 마지막 호출에 넘어온 자녀 프로필 ID. Provider가 ID를 제대로 전달하는지 확인할 때 쓴다.
  int? lastFetchChildProfileId;
  int? lastCreateChildProfileId;

  ApiException? fetchError;
  ApiException? createError;

  List<Character> characters = const [
    Character(
      characterId: 1,
      name: '토끼',
      personality: '용감함',
      description: '설명',
      type: CharacterType.preset,
    ),
  ];

  int _nextId = 100;

  @override
  Future<List<Character>> fetchCharacters(int childProfileId) async {
    fetchCalls++;
    lastFetchChildProfileId = childProfileId;
    if (fetchError != null) throw fetchError!;
    return characters;
  }

  @override
  Future<Character> createCharacter({
    required int childProfileId,
    required String name,
    String personality = '밝음',
    String description = '',
    String? imageUrl,
    String type = CharacterType.custom,
  }) async {
    createCalls++;
    lastCreateChildProfileId = childProfileId;
    if (createError != null) throw createError!;
    final character = Character(
      characterId: _nextId++,
      name: name,
      personality: personality,
      description: description,
      imageUrl: imageUrl,
      type: type,
    );
    lastCreated = character;
    return character;
  }
}
