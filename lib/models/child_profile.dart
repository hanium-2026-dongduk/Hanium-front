import 'json_parse.dart';

/// 학습 수준. 백엔드 `learning_level`이 받는 값과 같아야 한다.
enum LearningLevel {
  beginner('beginner', '초급'),
  intermediate('intermediate', '중급'),
  advanced('advanced', '고급');

  final String wireValue;
  final String label;

  const LearningLevel(this.wireValue, this.label);

  static LearningLevel fromWire(Object? value) {
    return LearningLevel.values.firstWhere(
      (level) => level.wireValue == value,
      // 서버 기본값이 beginner라 모르는 값이 와도 여기로 떨어뜨린다.
      orElse: () => LearningLevel.beginner,
    );
  }
}

/// 자녀 프로필. 보호자 계정 하나에 여러 개가 달린다. (P-AU-AU04)
/// 백엔드 경로는 `/api/children`이고 필드는 snake_case다.
/// (Hanium-back `docs/API_SPEC_PROFILE.md` 참고)
class ChildProfile {
  final int childProfileId;
  final String childName;

  /// 1~15. 선택 항목이라 없을 수 있다. 서버에 생년월일 컬럼은 없다.
  final int? age;

  final LearningLevel learningLevel;

  /// 자유 문자열(30자 이하). 서버가 값을 강제하지 않는다.
  final String? vocabularyLevel;

  /// 이미지 URL(500자 이하). 아바타 키가 아니라 URL이다.
  final String? profileImageUrl;

  /// 한 보호자에게 활성 프로필은 항상 최대 1개다.
  /// 전환은 별도 API(`PATCH /api/children/:id/activate`)로만 가능하다.
  final bool isActive;

  const ChildProfile({
    required this.childProfileId,
    required this.childName,
    this.age,
    this.learningLevel = LearningLevel.beginner,
    this.vocabularyLevel,
    this.profileImageUrl,
    this.isActive = false,
  });

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    childProfileId: parseId(json['child_profile_id']),
    childName: json['child_name'] as String? ?? '',
    age: parseOptionalInt(json['age']),
    learningLevel: LearningLevel.fromWire(json['learning_level']),
    vocabularyLevel: json['vocabulary_level'] as String?,
    profileImageUrl: json['profile_image_url'] as String?,
    isActive: json['is_active'] as bool? ?? false,
  );

  /// 생성/수정 요청 바디.
  ///
  /// 서버는 허용된 필드만 반영하고 나머지는 무시하며, **반영할 필드가 하나도 없으면 400**을
  /// 낸다. 그래서 값이 없는 선택 필드는 아예 키를 빼고 보낸다.
  Map<String, dynamic> toRequestJson() => {
    'child_name': childName,
    if (age != null) 'age': age,
    'learning_level': learningLevel.wireValue,
    if (vocabularyLevel != null && vocabularyLevel!.isNotEmpty)
      'vocabulary_level': vocabularyLevel,
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
      'profile_image_url': profileImageUrl,
  };

  ChildProfile copyWith({
    String? childName,
    int? age,
    LearningLevel? learningLevel,
    String? vocabularyLevel,
    String? profileImageUrl,
  }) {
    return ChildProfile(
      childProfileId: childProfileId,
      childName: childName ?? this.childName,
      age: age ?? this.age,
      learningLevel: learningLevel ?? this.learningLevel,
      vocabularyLevel: vocabularyLevel ?? this.vocabularyLevel,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive,
    );
  }
}
