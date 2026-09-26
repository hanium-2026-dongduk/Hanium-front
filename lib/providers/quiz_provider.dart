import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';

/// 동화 확인 퀴즈 한 번의 응시 상태. (P-ED-QZ01 생성, P-ED-QZ03 응시·결과)
///
/// **화면 단위 Provider다.** 앱 전역에 두지 않고 퀴즈 화면이 열릴 때마다 새로 만든다.
/// 자녀·동화가 생성자에 고정되므로 자녀가 바뀌어도 이전 자녀의 문항·답안이 남을 수 없다.
///
/// 백엔드는 같은 퀴즈를 다시 제출하면 포인트를 또 주고, 같은 동화로 `generate`를 다시
/// 부르면 문항을 교체한다. 그래서 채점이 끝난 뒤에는 [select]·[submit]을 막는다.
class QuizProvider extends ChangeNotifier {
  final QuizService _quizService;
  final int childProfileId;
  final int storyId;

  QuizProvider({required this._quizService, required this.childProfileId, required this.storyId});

  QuizSet? _quiz;
  int? _quizSetId;
  final Map<int, int> _selectedOptionIds = {};
  int _currentIndex = 0;
  QuizResult? _result;

  // 화면이 열리자마자 불러오므로 첫 프레임부터 로딩으로 시작한다.
  bool _isLoading = true;
  bool _isFetching = false;
  bool _isSubmitting = false;
  String? _loadError;
  String? _submitError;
  bool _disposed = false;

  QuizSet? get quiz => _quiz;
  List<QuizQuestion> get questions => _quiz?.questions ?? const [];
  int get currentIndex => _currentIndex;
  QuizQuestion? get currentQuestion =>
      _currentIndex < questions.length ? questions[_currentIndex] : null;
  bool get isLastQuestion => _currentIndex >= questions.length - 1;
  bool get isFirstQuestion => _currentIndex == 0;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get loadError => _loadError;
  String? get submitError => _submitError;

  /// 문항을 불러왔지만 하나도 없는 경우. (생성이 덜 끝났거나 서버 데이터가 비어 있음)
  bool get isEmpty => !_isLoading && _loadError == null && _quiz != null && questions.isEmpty;

  /// 채점이 끝났는지. 끝났다면 다시 풀거나 제출할 수 없다.
  bool get isSubmitted => _result != null;
  QuizResult? get result => _result;

  int? selectedOptionId(int questionId) => _selectedOptionIds[questionId];

  bool get isCurrentAnswered {
    final question = currentQuestion;
    return question != null && _selectedOptionIds.containsKey(question.questionId);
  }

  bool get allAnswered =>
      questions.isNotEmpty && questions.every((q) => _selectedOptionIds.containsKey(q.questionId));

  /// 퀴즈를 만들고(없을 때만) 문항을 불러온다.
  ///
  /// 생성은 성공했는데 조회만 실패했다면, 다시 시도할 때 생성을 반복하지 않는다.
  /// (생성을 다시 부르면 서버가 Gemini를 또 호출하고 문항을 교체한다.)
  Future<void> load() async {
    if (_result != null || _isFetching) return;
    _isFetching = true;
    _isLoading = true;
    _loadError = null;
    _safeNotify();

    try {
      final quizSetId =
          _quizSetId ??
          (await _quizService.generate(childProfileId: childProfileId, storyId: storyId)).quizSetId;
      _quizSetId = quizSetId;
      final quiz = await _quizService.fetchQuiz(
        childProfileId: childProfileId,
        quizSetId: quizSetId,
      );
      _quiz = quiz;
      _selectedOptionIds.clear();
      _currentIndex = 0;
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isFetching = false;
      _isLoading = false;
      _safeNotify();
    }
  }

  /// 현재 문항의 보기를 고른다. 채점 중이거나 채점이 끝났으면 무시한다.
  void select(int questionId, int optionId) {
    if (_isSubmitting || _result != null) return;
    final question = questions.where((q) => q.questionId == questionId).firstOrNull;
    if (question == null || !question.options.any((o) => o.optionId == optionId)) return;
    _selectedOptionIds[questionId] = optionId;
    _submitError = null;
    _safeNotify();
  }

  void next() {
    if (_currentIndex >= questions.length - 1) return;
    _currentIndex++;
    _safeNotify();
  }

  void previous() {
    if (_currentIndex <= 0) return;
    _currentIndex--;
    _safeNotify();
  }

  /// 모든 문항에 답했을 때만 제출한다. 성공하면 채점 결과를, 아니면 null을 돌려준다.
  /// 실패 이유는 [submitError]에 남고 답안은 그대로라서 다시 제출할 수 있다.
  Future<QuizResult?> submit() async {
    final quizSetId = _quizSetId;
    if (_isSubmitting || _result != null || quizSetId == null || !allAnswered) return null;

    _isSubmitting = true;
    _submitError = null;
    _safeNotify();

    try {
      final result = await _quizService.submit(
        childProfileId: childProfileId,
        quizSetId: quizSetId,
        answers: Map<int, int>.of(_selectedOptionIds),
      );
      _result = result;
      return result;
    } on ApiException catch (error) {
      _submitError = error.message;
      return null;
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }

  // 화면이 먼저 닫힌 뒤에 응답이 돌아와도 죽은 Provider를 건드리지 않게 한다.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
