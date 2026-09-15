import 'json_parse.dart';

/// 포인트 지급 사유. 백엔드 `REWARD_REASONS`와 같아야 한다.
/// (Hanium-back `src/services/reward.service.js`, `API_SPEC_REWARD.md` 7절)
enum RewardReason {
  attendance('attendance', '출석', '오늘 출석'),
  streakBonus('streak_bonus', '연속 출석 보너스', '연속 출석 보너스'),
  missionReward('mission_reward', '미션 보상', '미션 완료'),
  storyRead('story_read', '동화 읽기', '동화 완독'),
  wordClicked('word_clicked', '단어 학습', '단어 클릭'),
  quizAnswered('quiz_answered', '퀴즈 정답', '퀴즈 정답');

  final String wireValue;

  /// 필터칩 등 짧게 쓰는 라벨.
  final String label;

  /// 이력 목록 한 줄에 쓰는 설명.
  final String description;

  const RewardReason(this.wireValue, this.label, this.description);

  static RewardReason? fromWire(Object? value) {
    for (final reason in RewardReason.values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

/// 포인트 획득 이력 한 건. (P-GM-RW03)
class RewardHistoryEntry {
  final int points;
  final RewardReason? reason;
  final int balanceAfter;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const RewardHistoryEntry({
    required this.points,
    required this.reason,
    required this.balanceAfter,
    required this.createdAt,
    this.metadata = const {},
  });

  factory RewardHistoryEntry.fromJson(Map<String, dynamic> json) => RewardHistoryEntry(
    points: parseId(json['points']),
    reason: RewardReason.fromWire(json['reason']),
    balanceAfter: parseId(json['balanceAfter']),
    // 서버가 UTC로 내려주므로 화면 표시 전에 로컬로 바꾼다. (API_SPEC_REWARD.md 날짜/타임존 정책)
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
  );
}
