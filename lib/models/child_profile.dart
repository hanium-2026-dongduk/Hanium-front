/// 자녀 프로필. 보호자 계정 하나에 여러 개가 달린다. (P-AU-AU04)
class ChildProfile {
  final int id;
  final String name;
  final DateTime? birthDate;

  /// 캐릭터 이미지 식별자. 실제 이미지 매핑은 UI에서 정한다.
  final String? avatarKey;

  const ChildProfile({
    required this.id,
    required this.name,
    this.birthDate,
    this.avatarKey,
  });

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
    avatarKey: json['avatarKey'] as String?,
  );

  /// 생성/수정 요청 바디. id는 서버가 정하므로 보내지 않는다.
  Map<String, dynamic> toRequestJson() => {
    'name': name,
    // 시각은 필요 없어서 yyyy-MM-dd 형태로만 보낸다.
    if (birthDate != null)
      'birthDate': birthDate!.toIso8601String().split('T').first,
    if (avatarKey != null) 'avatarKey': avatarKey,
  };
}
