import 'json_parse.dart';

/// 배지 상태. 서버 값은 `earned | locked | coming_soon`.
/// (Hanium-back `badge.service.js`, 알 수 없는 값은 잠김으로 본다.)
enum BadgeState {
  earned,
  locked,
  comingSoon;

  static BadgeState fromServer(String? value) => switch (value) {
    'earned' => BadgeState.earned,
    'coming_soon' => BadgeState.comingSoon,
    _ => BadgeState.locked,
  };
}

/// 배지 획득 조건. 예: `{ type: streak_days, value: 10 }`
class BadgeCondition {
  final String type;
  final int value;

  const BadgeCondition({required this.type, required this.value});

  factory BadgeCondition.fromJson(Map<String, dynamic> json) =>
      BadgeCondition(type: json['type'] as String? ?? '', value: parseId(json['value']));

  /// 잠긴 배지를 눌렀을 때 아이에게 보여줄 획득 방법 문구.
  String get hint => switch (type) {
    'attendance_total' => '출석을 $value번 하면 받을 수 있어요',
    'streak_days' => '$value일 연속으로 출석하면 받을 수 있어요',
    'total_points' => '마법 토큰을 $value개 모으면 받을 수 있어요',
    'level' => '레벨 $value에 도달하면 받을 수 있어요',
    'mission_completed_total' => '미션을 $value번 완료하면 받을 수 있어요',
    'story_read_total' => '동화를 $value편 읽으면 받을 수 있어요',
    'quiz_correct_total' => '퀴즈를 $value문제 맞히면 받을 수 있어요',
    'vocabulary_saved_total' => '단어를 $value개 저장하면 받을 수 있어요',
    _ => '조금만 더 힘내면 받을 수 있어요',
  };
}

/// `GET /badges/:childId`의 배지 한 개. 이 응답은 snake_case다.
/// (Flutter의 `Badge` 위젯과 이름이 겹치지 않도록 `BadgeStatus`로 둔다.)
class BadgeStatus {
  final String badgeCode;
  final String name;
  final String description;
  final String? iconKey;
  final BadgeCondition condition;
  final BadgeState state;
  final DateTime? awardedAt;

  const BadgeStatus({
    required this.badgeCode,
    required this.name,
    required this.description,
    this.iconKey,
    required this.condition,
    required this.state,
    this.awardedAt,
  });

  bool get isEarned => state == BadgeState.earned;

  factory BadgeStatus.fromJson(Map<String, dynamic> json) => BadgeStatus(
    badgeCode: json['badge_code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    iconKey: json['icon_key'] as String?,
    condition: json['condition'] is Map
        ? BadgeCondition.fromJson(Map<String, dynamic>.from(json['condition'] as Map))
        : const BadgeCondition(type: '', value: 0),
    state: BadgeState.fromServer(json['status'] as String?),
    awardedAt: DateTime.tryParse(json['awarded_at'] as String? ?? '')?.toLocal(),
  );
}

/// `GET /badges/:childId` 응답 전체.
class BadgeSummary {
  final List<BadgeStatus> badges;
  final int earnedCount;
  final int totalCount;

  const BadgeSummary({required this.badges, required this.earnedCount, required this.totalCount});

  factory BadgeSummary.fromJson(Map<String, dynamic> json) {
    final badges = (json['badges'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BadgeStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return BadgeSummary(
      badges: badges,
      earnedCount: parseId(json['earned_count']),
      totalCount: json['total_count'] == null ? badges.length : parseId(json['total_count']),
    );
  }
}
