import 'json_parse.dart';

/// 하루 학습(앱 사용) 시간.
class UsageDay {
  /// `YYYY-MM-DD` (Asia/Seoul 기준)
  final String date;
  final int accumulatedSeconds;

  const UsageDay({required this.date, required this.accumulatedSeconds});

  factory UsageDay.fromJson(Map<String, dynamic> json) => UsageDay(
    date: json['date'] as String? ?? '',
    accumulatedSeconds: parseId(json['accumulatedSeconds']),
  );
}

/// `GET /usage/:childId/summary` 응답. 학습 통계 화면(MP03)이 쓴다.
///
/// 기록이 있는 날만 [days]에 담겨 온다.
class UsageSummary {
  final String from;
  final String to;
  final int totalAccumulatedSeconds;
  final List<UsageDay> days;

  const UsageSummary({
    required this.from,
    required this.to,
    required this.totalAccumulatedSeconds,
    this.days = const [],
  });

  factory UsageSummary.fromJson(Map<String, dynamic> json) => UsageSummary(
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    totalAccumulatedSeconds: parseId(json['totalAccumulatedSeconds']),
    days: (json['days'] as List? ?? const [])
        .whereType<Map>()
        .map((day) => UsageDay.fromJson(Map<String, dynamic>.from(day)))
        .toList(),
  );
}
