import 'json_parse.dart';

/// 다음 레벨까지 남은 정보. 최고 레벨(10)에서는 서버가 둘 다 null로 준다.
/// (`API_SPEC_REWARD.md` 5절)
class LevelProgress {
  final int currentLevelFloor;
  final int? nextLevelAt;
  final int? pointsToNextLevel;

  const LevelProgress({
    required this.currentLevelFloor,
    this.nextLevelAt,
    this.pointsToNextLevel,
  });

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
    currentLevelFloor: parseId(json['currentLevelFloor']),
    nextLevelAt: parseOptionalInt(json['nextLevelAt']),
    pointsToNextLevel: parseOptionalInt(json['pointsToNextLevel']),
  );
}

/// `GET /rewards/:childId` 응답. 포인트·레벨·연속출석을 한 번에 담는다.
/// (P-GM-RW02, P-GM-RW04, `API_SPEC_REWARD.md` 5절)
class RewardDetail {
  final int childProfileId;
  final int points;
  final int level;
  final int streakDays;
  final LevelProgress? levelProgress;

  const RewardDetail({
    required this.childProfileId,
    required this.points,
    required this.level,
    required this.streakDays,
    this.levelProgress,
  });

  factory RewardDetail.fromJson(Map<String, dynamic> json) => RewardDetail(
    childProfileId: parseId(json['childProfileId']),
    points: parseId(json['points']),
    level: parseId(json['level']),
    streakDays: parseId(json['streakDays']),
    levelProgress: json['levelProgress'] is Map
        ? LevelProgress.fromJson(Map<String, dynamic>.from(json['levelProgress'] as Map))
        : null,
  );
}
