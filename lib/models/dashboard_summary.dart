import 'json_parse.dart';

/// 퀴즈 응시 통계. (P-MY-MP03)
class QuizStats {
  final int totalAttempts;

  /// 응시 기록이 없으면 서버가 null을 준다.
  final double? averageScore;
  final DateTime? lastAttemptAt;

  const QuizStats({
    required this.totalAttempts,
    this.averageScore,
    this.lastAttemptAt,
  });

  factory QuizStats.fromJson(Map<String, dynamic> json) => QuizStats(
    totalAttempts: parseId(json['totalAttempts']),
    averageScore: (json['averageScore'] as num?)?.toDouble(),
    lastAttemptAt: DateTime.tryParse(
      json['lastAttemptAt'] as String? ?? '',
    )?.toLocal(),
  );
}

/// `GET /dashboard/:childId` 응답. 학습 통계 화면(MP03)이 쓴다.
class DashboardSummary {
  final int storyCount;
  final int favoriteStoryCount;

  /// 지금까지 한 번이라도 열어 본 동화 수. 같은 동화를 여러 번 읽어도 1로 센다.
  final int readStoryCount;
  final int vocabularyCount;
  final QuizStats quizStats;

  const DashboardSummary({
    required this.storyCount,
    required this.favoriteStoryCount,
    this.readStoryCount = 0,
    required this.vocabularyCount,
    required this.quizStats,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        storyCount: parseId(json['storyCount']),
        favoriteStoryCount: parseId(json['favoriteStoryCount']),
        readStoryCount: parseId(json['readStoryCount']),
        vocabularyCount: parseId(json['vocabularyCount']),
        quizStats: json['quizStats'] is Map
            ? QuizStats.fromJson(
                Map<String, dynamic>.from(json['quizStats'] as Map),
              )
            : const QuizStats(totalAttempts: 0),
      );
}
