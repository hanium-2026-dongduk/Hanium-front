import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/character.dart';
import 'package:hanium_front/services/character_service.dart';

/// 캐릭터 Provider·화면 테스트용 가짜 CharacterService.
class FakeCharacterService implements CharacterService {
  int fetchCalls = 0;
  int createCalls = 0;
  Character? lastCreated;

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
  Future<List<Character>> fetchCharacters() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return characters;
  }

  @override
  Future<Character> createCharacter({
    required String name,
    String personality = '밝음',
    String description = '',
    String? imageUrl,
    String type = CharacterType.custom,
  }) async {
    createCalls++;
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
