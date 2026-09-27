import 'json_parse.dart';

/// 백엔드 `character.model.js`의 `type` 값.
class CharacterType {
  CharacterType._();

  static const preset = 'PRESET';
  static const custom = 'CUSTOM';
  static const random = 'RANDOM';
}

/// 동화 속 캐릭터. (P-SG01)
///
/// `GET/POST /api/characters`는 원시 Sequelize row를 그대로 내려줘서
/// snake_case(`character_id`, `image_url`)로 온다.
class Character {
  final int characterId;
  final String name;
  final String personality;
  final String description;
  final String? imageUrl;
  final String type;

  const Character({
    required this.characterId,
    required this.name,
    required this.personality,
    required this.description,
    this.imageUrl,
    required this.type,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      characterId: parseId(json['character_id'] ?? json['characterId']),
      name: json['name'] as String? ?? '',
      personality: json['personality'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      type: json['type'] as String? ?? CharacterType.custom,
    );
  }
}
