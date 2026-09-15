import 'json_parse.dart';

/// `POST /attendance/check` 응답. (P-GM-RW02)
///
/// **멱등하다.** 같은 날 몇 번을 호출해도 안전하다 — `alreadyChecked`로 이미
/// 출석했는지만 보고, `pointsEarned`가 0보다 클 때만 획득 연출을 띄우면 된다.
/// (`API_SPEC_REWARD.md` 1절)
class AttendanceCheckResult {
  final bool alreadyChecked;
  final String attendanceDate;
  final int streakDays;
  final int pointsEarned;
  final List<String> badgesAwarded;

  const AttendanceCheckResult({
    required this.alreadyChecked,
    required this.attendanceDate,
    required this.streakDays,
    required this.pointsEarned,
    this.badgesAwarded = const [],
  });

  factory AttendanceCheckResult.fromJson(Map<String, dynamic> json) => AttendanceCheckResult(
    alreadyChecked: json['alreadyChecked'] as bool? ?? false,
    attendanceDate: json['attendanceDate'] as String? ?? '',
    streakDays: parseId(json['streakDays']),
    pointsEarned: parseId(json['pointsEarned']),
    badgesAwarded: (json['badgesAwarded'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

/// `GET /attendance/:childId?month=YYYY-MM` 응답. (P-GM-RW02)
class AttendanceMonth {
  final int childProfileId;
  final String month;
  final List<String> attendedDates;
  final int attendedCount;
  final int denominator;
  final double attendanceRate;
  final int currentStreak;

  const AttendanceMonth({
    required this.childProfileId,
    required this.month,
    required this.attendedDates,
    required this.attendedCount,
    required this.denominator,
    required this.attendanceRate,
    required this.currentStreak,
  });

  factory AttendanceMonth.fromJson(Map<String, dynamic> json) => AttendanceMonth(
    childProfileId: parseId(json['childProfileId']),
    month: json['month'] as String? ?? '',
    attendedDates: (json['attendedDates'] as List?)?.whereType<String>().toList() ?? const [],
    attendedCount: parseId(json['attendedCount']),
    denominator: parseId(json['denominator']),
    attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
    currentStreak: parseId(json['currentStreak']),
  );
}

/// 연속 출석 마일스톤 보너스 정책. (`API_SPEC_REWARD.md` 날짜/타임존 정책 절)
/// 정확히 일치하는 날 1회만 지급되므로, 화면에서는 "다음 마일스톤까지 남은 일수"를
/// 보여주는 데 쓴다.
class StreakMilestones {
  StreakMilestones._();

  static const Map<int, int> bonusByDays = {3: 20, 7: 50, 14: 100, 30: 300};

  /// 현재 연속일수 기준으로 다음에 도달할 마일스톤. 이미 최대(30일 이상)를
  /// 넘겼으면 null.
  static int? nextMilestone(int currentStreak) {
    for (final day in bonusByDays.keys) {
      if (currentStreak < day) return day;
    }
    return null;
  }
}
