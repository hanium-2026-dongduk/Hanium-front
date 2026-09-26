import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/reward_provider.dart';
import '../../services/quiz_service.dart';
import '../../services/tts_service.dart';
import '../../theme/theme.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/reward_celebration.dart';

/// 동화 확인 퀴즈. 응시(P-ED-QZ03)부터 채점 결과까지 한 화면에서 보여준다.
///
/// 동화를 읽은 뒤 진입하고(P-ED-QZ02), 닫힐 때 **채점까지 끝났는지**를 `bool`로 돌려준다.
/// 호출한 화면은 `true`를 받으면 같은 퀴즈로 다시 들어오지 못하게 막아야 한다.
/// (백엔드는 같은 퀴즈를 다시 제출하면 포인트를 또 준다.)
///
/// 화면을 열 때마다 [QuizProvider]를 새로 만든다. 자녀·동화가 Provider 생성자에 고정되어
/// 이전 응시의 문항이나 답안이 다음 화면에 남지 않는다.
class QuizScreen extends StatelessWidget {
  final int storyId;

  const QuizScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context) {
    final childProfileId = context.read<ActiveChildProvider>().childProfileId;
    if (childProfileId == null) {
      return Scaffold(
        appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white)),
        body: SafeArea(
          child: CenteredMessage(
            message: '먼저 자녀 프로필을 선택해 주세요.',
            actionLabel: '돌아가기',
            onAction: () => Navigator.of(context).maybePop(false),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<QuizProvider>(
      create: (context) => QuizProvider(
        quizService: context.read<QuizService>(),
        childProfileId: childProfileId,
        storyId: storyId,
      ),
      child: const _QuizView(),
    );
  }
}

class _QuizView extends StatefulWidget {
  const _QuizView();

  @override
  State<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<_QuizView> {
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuizProvider>().load();
    });
  }

  @override
  void dispose() {
    // 재생 중인 발음이 화면과 함께 끊기도록 한다.
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _speak(String text) => _tts.speak(text);

  /// 뒤로가기·건너뛰기 모두 여기로 모인다. 채점까지 끝났는지를 돌려준다.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final quiz = context.read<QuizProvider>();
    // 제출 요청이 나간 상태로 나가면 결과를 놓쳐 재응시가 열리므로 기다린다.
    if (quiz.isSubmitting) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('채점하고 있어요. 잠깐만 기다려 주세요!')));
      return;
    }

    // 고른 답이 있는 채로 나가려 하면 실수로 잃지 않도록 한 번 더 묻는다.
    if (!quiz.isSubmitted && quiz.hasAnyAnswer) {
      final leave = await showConfirmDialog(
        context,
        title: '퀴즈를 그만할까요?',
        content: '지금까지 고른 답은 저장되지 않아요.',
        cancelLabel: '계속 풀래요',
        confirmLabel: '그만할래요',
      );
      if (!leave || !mounted) return;
    }
    // 확인창이 떠 있는 동안 상태가 바뀌었을 수 있어 다시 읽는다.
    // 제출 중 안내가 다음 화면까지 남지 않게 한다.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pop(quiz.isSubmitted);
  }

  Future<void> _submit() async {
    final quiz = context.read<QuizProvider>();
    final rewardProvider = context.read<RewardProvider>();

    final result = await quiz.submit();
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // 포인트가 바뀌었으니 메인 화면 토큰 표시를 먼저 갱신한다.
    // 이때 레벨이 올랐는지도 알 수 있어서 축하 연출은 그 뒤에 띄운다.
    await rewardProvider.refresh(quiz.childProfileId);
    if (!mounted) return;
    final newLevel = rewardProvider.takeLevelUp();

    if (result.pointsEarned > 0 || result.badgesAwarded.isNotEmpty || newLevel != null) {
      unawaited(
        showRewardCelebration(
          context,
          points: result.pointsEarned,
          badgeCount: result.badgesAwarded.length,
          newLevel: newLevel,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: AppTheme.navyColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            quiz.isSubmitted ? '퀴즈 결과' : '동화 확인 퀴즈',
            style: const TextStyle(color: AppTheme.yellowColor, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(child: _buildBody(quiz)),
      ),
    );
  }

  Widget _buildBody(QuizProvider quiz) {
    if (quiz.isLoading) return const _QuizLoading();

    // 빈 상태에도 다시 시도할 수 있어야 한다. (AsyncStateView는 오류일 때만 버튼을 보여준다.)
    if (quiz.loadError == null && quiz.isEmpty) {
      return CenteredMessage(
        message: '퀴즈가 아직 준비되지 않았어요.\n조금 있다가 다시 해 볼까요?',
        actionLabel: '다시 해 볼래요',
        onAction: quiz.load,
      );
    }

    return AsyncStateView(
      isLoading: false,
      errorMessage: quiz.loadError,
      onRetry: quiz.load,
      contentBuilder: (_) => quiz.isSubmitted
          ? _QuizResultView(quiz: quiz, onDone: () => Navigator.of(context).maybePop())
          : _QuizQuestionView(
              quiz: quiz,
              onSpeak: _speak,
              onSubmit: _submit,
              onSkip: () => Navigator.of(context).maybePop(),
            ),
    );
  }
}

class _QuizLoading extends StatelessWidget {
  const _QuizLoading();

  @override
  Widget build(BuildContext context) {
    // 문항을 만드는 데 몇 초 걸릴 수 있어서, 멈춘 게 아니라는 안내를 함께 보여준다.
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.yellowColor),
          SizedBox(height: 20),
          Text('마법사가 퀴즈를 만들고 있어요...', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}

/// 한 문항씩 푸는 화면. 서버가 제출 때에만 채점하므로 여기서는 정답을 알려주지 않는다.
class _QuizQuestionView extends StatelessWidget {
  final QuizProvider quiz;
  final Future<void> Function(String text) onSpeak;
  final Future<void> Function() onSubmit;
  final VoidCallback onSkip;

  const _QuizQuestionView({
    required this.quiz,
    required this.onSpeak,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final question = quiz.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    final total = quiz.questions.length;
    final position = quiz.currentIndex + 1;
    final selectedId = quiz.selectedOptionId(question.questionId);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProgressHeader(position: position, total: total),
                    const SizedBox(height: 16),
                    _QuestionCard(question: question, onSpeak: onSpeak),
                    const SizedBox(height: 16),
                    _OptionGrid(
                      children: [
                        for (var i = 0; i < question.options.length; i++)
                          _OptionTile(
                            key: ValueKey('option-${question.options[i].optionId}'),
                            number: i + 1,
                            text: question.options[i].text,
                            state: question.options[i].optionId == selectedId
                                ? _OptionState.selected
                                : _OptionState.idle,
                            onTap: quiz.isSubmitting
                                ? null
                                : () => quiz.select(
                                    question.questionId,
                                    question.options[i].optionId,
                                  ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _BottomBar(quiz: quiz, onSubmit: onSubmit, onSkip: onSkip),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int position;
  final int total;

  const _ProgressHeader({required this.position, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : position / total,
              minHeight: 12,
              color: AppTheme.pastelBlue,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Q$position / $total',
          style: const TextStyle(
            color: AppTheme.pastelBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final Future<void> Function(String text) onSpeak;

  const _QuestionCard({required this.question, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.pastelPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '동화 내용 확인',
                  style: TextStyle(
                    color: AppTheme.navyColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => onSpeak(question.text),
                icon: const Icon(Icons.volume_up, color: AppTheme.yellowColor),
                label: const Text(
                  '발음 듣기',
                  style: TextStyle(color: AppTheme.yellowColor, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: AppTheme.yellowColor, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 넓은 화면(태블릿 가로)에서는 2열, 좁으면 1열로 보기를 놓는다.
class _OptionGrid extends StatelessWidget {
  final List<Widget> children;

  const _OptionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final twoColumns = constraints.maxWidth >= 600;
        final itemWidth = twoColumns ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
        );
      },
    );
  }
}

enum _OptionState { idle, selected, correct, wrong, missed }

/// 보기 한 개. 색만으로 구분하지 않도록 채점 후에는 아이콘도 함께 쓴다.
class _OptionTile extends StatelessWidget {
  final int number;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({
    super.key,
    required this.number,
    required this.text,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill) = switch (state) {
      _OptionState.selected => (AppTheme.yellowColor, AppTheme.yellowColor.withValues(alpha: 0.15)),
      _OptionState.correct => (AppTheme.pastelGreen, AppTheme.pastelGreen.withValues(alpha: 0.2)),
      _OptionState.wrong => (AppTheme.pastelPink, AppTheme.pastelPink.withValues(alpha: 0.2)),
      _OptionState.missed => (Colors.white24, Colors.white.withValues(alpha: 0.04)),
      _OptionState.idle => (Colors.white24, Colors.white.withValues(alpha: 0.06)),
    };

    final stateLabel = switch (state) {
      _OptionState.selected => '선택했어요',
      _OptionState.correct => '정답',
      _OptionState.wrong => '내가 고른 답',
      _ => null,
    };

    // '선택됨'은 selected 상태로 읽히므로 라벨에는 채점 표시만 넣는다.
    final announced = state == _OptionState.selected ? null : stateLabel;

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: state == _OptionState.selected,
      label: '$number번 $text${announced == null ? '' : ', $announced'}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: state == _OptionState.idle ? 1.5 : 3),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _OptionBadge(number: number, state: state, borderColor: border),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (stateLabel != null)
                    Text(
                      stateLabel,
                      style: TextStyle(color: border, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  final int number;
  final _OptionState state;
  final Color borderColor;

  const _OptionBadge({required this.number, required this.state, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    // 오답에 ✕를 쓰면 아이에게 야단치는 느낌이라, 고른 답이라는 뜻의 부드러운 아이콘을 쓴다.
    final icon = switch (state) {
      _OptionState.correct => Icons.check,
      _OptionState.wrong => Icons.touch_app_outlined,
      _ => null,
    };
    final isSelected = state == _OptionState.selected;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppTheme.yellowColor : Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: icon != null
          ? Icon(icon, color: borderColor, size: 24)
          : Text(
              '$number',
              style: TextStyle(
                color: isSelected ? AppTheme.navyColor : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final QuizProvider quiz;
  final Future<void> Function() onSubmit;
  final VoidCallback onSkip;

  const _BottomBar({required this.quiz, required this.onSubmit, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final isLast = quiz.isLastQuestion;
    // 마지막 문항에서는 모든 문항에 답해야 제출할 수 있다. (서버가 제출 때만 채점한다.)
    final canProceed = quiz.isCurrentAnswered && (!isLast || quiz.allAnswered);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quiz.submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    quiz.submitError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.pastelPink, fontSize: 14),
                  ),
                ),
              // 좁은 화면에서는 건너뛰기가 윗줄로 넘어가도록 Wrap을 쓴다.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: quiz.isSubmitting ? null : onSkip,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: const Text(
                      '퀴즈 건너뛰기',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!quiz.isFirstQuestion)
                        TextButton(
                          onPressed: quiz.isSubmitting ? null : quiz.previous,
                          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                          child: const Text(
                            '이전',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: !canProceed || quiz.isSubmitting
                            ? null
                            : (isLast ? onSubmit : quiz.next),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 56),
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white38,
                        ),
                        child: quiz.isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppTheme.navyColor,
                                ),
                              )
                            : Text(isLast ? '제출하기' : '다음 →'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 채점 결과. 문항마다 정답과 내가 고른 답을 보여준다.
class _QuizResultView extends StatelessWidget {
  final QuizProvider quiz;
  final VoidCallback onDone;

  const _QuizResultView({required this.quiz, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final result = quiz.result!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ScoreCard(result: result),
                      const SizedBox(height: 24),
                      const Text(
                        '문제별 정답 확인',
                        style: TextStyle(
                          color: AppTheme.yellowColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final question in quiz.questions) ...[
                        _ReviewCard(
                          question: question,
                          answer: result.answerFor(question.questionId),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  child: const Text('완료'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final QuizResult result;

  const _ScoreCard({required this.result});

  String get _message {
    if (result.totalQuestions > 0 && result.correctCount == result.totalQuestions) {
      return '모두 맞혔어요! 대단해요!';
    }
    if (result.score >= 60) return '잘했어요! 조금만 더 힘내요!';
    return '괜찮아요! 다음엔 더 잘할 수 있어요!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.yellowColor, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: AppTheme.yellowColor, size: 56),
          const SizedBox(height: 8),
          Text(
            '${result.totalQuestions}문제 중 ${result.correctCount}문제 맞혔어요!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          if (result.pointsEarned > 0) ...[
            const SizedBox(height: 12),
            Text(
              '마법 토큰 +${result.pointsEarned}',
              style: const TextStyle(
                color: AppTheme.pastelBlue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final QuizQuestion question;
  final QuizAnswerResult? answer;

  const _ReviewCard({required this.question, required this.answer});

  _OptionState _stateOf(QuizOption option) {
    if (option.optionId == answer?.correctOptionId) return _OptionState.correct;
    if (option.optionId == answer?.selectedOptionId) return _OptionState.wrong;
    return _OptionState.missed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Q${question.questionOrder}. ${question.text}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _OptionGrid(
            children: [
              for (var i = 0; i < question.options.length; i++)
                _OptionTile(
                  number: i + 1,
                  text: question.options[i].text,
                  state: _stateOf(question.options[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
