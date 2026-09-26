import 'dart:async';

import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/quiz.dart';
import 'package:hanium_front/services/quiz_service.dart';

/// 퀴즈 Provider·화면 테스트용 가짜 QuizService.
///
/// 문항 2개(보기 각 2개)를 돌려주고, 정답은 항상 각 문항의 첫 번째 보기다.
/// 호출 횟수와 마지막 제출 답안을 기록해 재제출·재생성 방지를 검증할 수 있다.
class FakeQuizService implements QuizService {
  int generateCalls = 0;
  int fetchCalls = 0;
  int submitCalls = 0;
  Map<int, int>? lastAnswers;

  ApiException? generateError;
  ApiException? fetchError;
  ApiException? submitError;

  /// null이 아니면 submit이 이 Completer가 끝날 때까지 기다린다.
  Completer<void>? submitGate;

  List<QuizQuestion> questions = defaultQuestions();
  int pointsEarned = 10;
  bool leveledUp = false;
  List<String> badgesAwarded = const [];

  static List<QuizQuestion> defaultQuestions() => const [
    QuizQuestion(
      questionId: 101,
      questionOrder: 1,
      text: 'Where did the bunny go?',
      options: [
        QuizOption(optionId: 1001, optionOrder: 1, text: 'Candy Forest'),
        QuizOption(optionId: 1002, optionOrder: 2, text: 'Cookie Castle'),
      ],
    ),
    QuizQuestion(
      questionId: 102,
      questionOrder: 2,
      text: 'Who helped the bunny?',
      options: [
        QuizOption(optionId: 1003, optionOrder: 1, text: 'A little bird'),
        QuizOption(optionId: 1004, optionOrder: 2, text: 'A big bear'),
      ],
    ),
  ];

  @override
  Future<QuizGeneration> generate({required int childProfileId, required int storyId}) async {
    generateCalls++;
    if (generateError != null) throw generateError!;
    return QuizGeneration(quizSetId: 7, status: 'ready', questionCount: questions.length);
  }

  @override
  Future<QuizSet> fetchQuiz({required int childProfileId, required int quizSetId}) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return QuizSet(quizSetId: quizSetId, status: 'ready', questions: questions);
  }

  @override
  Future<QuizResult> submit({
    required int childProfileId,
    required int quizSetId,
    required Map<int, int> answers,
  }) async {
    submitCalls++;
    lastAnswers = Map.of(answers);
    if (submitGate != null) await submitGate!.future;
    if (submitError != null) throw submitError!;

    final graded = [
      for (final question in questions)
        QuizAnswerResult(
          questionId: question.questionId,
          selectedOptionId: answers[question.questionId],
          correctOptionId: question.options.first.optionId,
          isCorrect: answers[question.questionId] == question.options.first.optionId,
        ),
    ];
    final correct = graded.where((a) => a.isCorrect).length;
    return QuizResult(
      attemptId: 55,
      totalQuestions: questions.length,
      correctCount: correct,
      score: (correct / questions.length * 100).round(),
      answers: graded,
      pointsEarned: pointsEarned,
      leveledUp: leveledUp,
      badgesAwarded: badgesAwarded,
    );
  }
}
