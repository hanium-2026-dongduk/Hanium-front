import 'json_parse.dart';

/// `POST /quizzes/generate` 응답. 문항은 들어 있지 않아서 [QuizSet]을 따로 조회해야 한다.
/// (P-ED-QZ01, Hanium-back `quizGeneration.service.js`)
class QuizGeneration {
  final int quizSetId;
  final String status;
  final int questionCount;

  const QuizGeneration({
    required this.quizSetId,
    required this.status,
    required this.questionCount,
  });

  factory QuizGeneration.fromJson(Map<String, dynamic> json) => QuizGeneration(
    quizSetId: parseId(json['quizSetId']),
    status: json['status'] as String? ?? '',
    questionCount: parseId(json['questionCount']),
  );
}

/// 문항의 보기 한 개. 응답에는 정답 여부가 없다. (제출 후 채점 결과로만 알 수 있다.)
class QuizOption {
  final int optionId;
  final int optionOrder;
  final String text;

  const QuizOption({required this.optionId, required this.optionOrder, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    optionId: parseId(json['optionId']),
    optionOrder: parseId(json['optionOrder']),
    text: json['optionText'] as String? ?? '',
  );
}

class QuizQuestion {
  final int questionId;
  final int questionOrder;
  final String text;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.questionId,
    required this.questionOrder,
    required this.text,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    questionId: parseId(json['questionId']),
    questionOrder: parseId(json['questionOrder']),
    text: json['questionText'] as String? ?? '',
    options: _parseList(json['options'], QuizOption.fromJson),
  );
}

/// `GET /quizzes/:id` 응답. 생성이 끝난 퀴즈의 문항·보기. (P-ED-QZ03)
class QuizSet {
  final int quizSetId;
  final String status;
  final List<QuizQuestion> questions;

  const QuizSet({required this.quizSetId, required this.status, required this.questions});

  factory QuizSet.fromJson(Map<String, dynamic> json) => QuizSet(
    quizSetId: parseId(json['quizSetId']),
    status: json['status'] as String? ?? '',
    questions: _parseList(json['questions'], QuizQuestion.fromJson),
  );
}

/// 채점된 문항 한 개.
class QuizAnswerResult {
  final int questionId;

  /// 고르지 않은 문항이면 null.
  final int? selectedOptionId;
  final int? correctOptionId;
  final bool isCorrect;

  const QuizAnswerResult({
    required this.questionId,
    this.selectedOptionId,
    this.correctOptionId,
    required this.isCorrect,
  });

  factory QuizAnswerResult.fromJson(Map<String, dynamic> json) => QuizAnswerResult(
    questionId: parseId(json['questionId']),
    selectedOptionId: parseOptionalInt(json['selectedOptionId']),
    correctOptionId: parseOptionalInt(json['correctOptionId']),
    isCorrect: json['isCorrect'] == true,
  );
}

/// `POST /quizzes/:id/submit` 응답. (P-ED-QZ03)
///
/// [pointsEarned]는 정답당 5점만 센다. 오늘의 미션 보상(+20)은 포함되지 않는다.
class QuizResult {
  final int attemptId;
  final int totalQuestions;
  final int correctCount;
  final int score;
  final List<QuizAnswerResult> answers;
  final int pointsEarned;
  final bool leveledUp;
  final List<String> badgesAwarded;

  const QuizResult({
    required this.attemptId,
    required this.totalQuestions,
    required this.correctCount,
    required this.score,
    required this.answers,
    required this.pointsEarned,
    required this.leveledUp,
    this.badgesAwarded = const [],
  });

  /// 문항 id로 채점 결과를 찾는다. 없으면 null.
  QuizAnswerResult? answerFor(int questionId) {
    for (final answer in answers) {
      if (answer.questionId == questionId) return answer;
    }
    return null;
  }

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    attemptId: parseId(json['attemptId']),
    totalQuestions: parseId(json['totalQuestions']),
    correctCount: parseId(json['correctCount']),
    score: parseId(json['score']),
    answers: _parseList(json['answers'], QuizAnswerResult.fromJson),
    pointsEarned: parseId(json['pointsEarned']),
    leveledUp: json['leveledUp'] == true,
    badgesAwarded: (json['badgesAwarded'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

List<T> _parseList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
}
