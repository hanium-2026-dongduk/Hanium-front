import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import 'package:hanium_front/core/api_config.dart';
import 'package:hanium_front/models/story_payload.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/story_result_provider.dart';
import 'package:hanium_front/screens/quiz/quiz_screen.dart';
import 'package:hanium_front/services/story_service.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/widgets/async_state_view.dart';

/// 동화 생성 결과([payload])이거나 라이브러리에서 다시 여는 상세([storyId])다.
/// 실제 생성/조회는 [StoryResultProvider]가 한다.
class StoryResultScreen extends StatelessWidget {
  final StoryCreatePayload? payload;

  /// 서버에 저장된 동화의 id. 라이브러리에서 열 때는 이 값만 온다.
  final int? storyId;

  /// 라이브러리 목록이 이미 알고 있는 즐겨찾기 여부. 상세 조회 응답에는
  /// 이 값이 없어서 화면 진입 시점에 넘겨받는다.
  final bool initialIsFavorite;

  const StoryResultScreen({
    super.key,
    this.payload,
    this.storyId,
    this.initialIsFavorite = false,
  }) : assert(
  payload != null || storyId != null,
  'payload(생성) 또는 storyId(조회) 중 하나는 있어야 한다',
  );

  @override
  Widget build(BuildContext context) {
    final activeChild = context.read<ActiveChildProvider>();
    final childProfileId = activeChild.childProfileId;
    if (childProfileId == null) {
      return Scaffold(
        appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white)),
        body: SafeArea(
          child: CenteredMessage(
            message: '먼저 자녀 프로필을 선택해 주세요.',
            actionLabel: '돌아가기',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<StoryResultProvider>(
      create: (context) => StoryResultProvider(
        storyService: context.read<StoryService>(),
        childProfileId: childProfileId,
        payload: payload,
        initialStoryId: storyId,
        // 서버 프롬프트의 난이도·어휘 수준에 반영되므로 생성 모드에서 자녀 나이를 넘긴다.
        childAge: activeChild.activeChild?.age,
        initialIsFavorite: initialIsFavorite,
      ),
      child: const _StoryResultView(),
    );
  }
}

class _StoryResultView extends StatefulWidget {
  const _StoryResultView();

  @override
  State<_StoryResultView> createState() => _StoryResultViewState();
}

class _StoryResultViewState extends State<_StoryResultView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentPage = 0;
  bool _isPlaying = false;
  bool _isQuizOpen = false;

  /// 퀴즈를 끝까지 풀어 채점까지 마쳤는지. 마쳤다면 다시 열지 못하게 한다.
  bool _isQuizDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StoryResultProvider>().load();
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
        unawaited(_audioPlayer.seek(Duration.zero));
      }
      // 플랫폼 채널이 없는 테스트 환경 등에서 스트림 오류로 화면이 죽지 않게 한다.
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String? audioUrl) async {
    if (audioUrl == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    try {
      await _audioPlayer.setUrl(ApiConfig.resolveMediaUrl(audioUrl));
      await _audioPlayer.play();
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오디오를 재생할 수 없어요.')));
    }
  }

  /// 오디오를 멈추고 페이지를 옮긴다. [delta]는 -1(이전)·+1(다음).
  Future<void> _changePage(int delta, int totalPages) async {
    final next = _currentPage + delta;
    if (next < 0 || next >= totalPages) return;
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _currentPage = next;
      _isPlaying = false;
    });
  }

  Future<void> _toggleFavorite() async {
    final provider = context.read<StoryResultProvider>();
    await provider.toggleFavorite();
    if (!mounted) return;
    final error = provider.favoriteError;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _openQuiz(int storyId) async {
    if (_isQuizOpen || _isQuizDone) return;
    _isQuizOpen = true;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => QuizScreen(storyId: storyId)),
    );
    _isQuizOpen = false;
    if (!mounted) return;
    if (completed == true) setState(() => _isQuizDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryResultProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          provider.isLoading ? '만드는 중...' : (provider.story?.title ?? '생성 완료!'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text(
              '처음으로',
              style: TextStyle(color: AppTheme.yellowColor),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: provider.isLoading
            ? _StoryLoading(isCreating: provider.payload != null)
            : AsyncStateView(
          isLoading: false,
          errorMessage: provider.loadError,
          onRetry: provider.load,
          isEmpty: provider.story?.pages.isEmpty ?? false,
          emptyMessage: '표시할 동화 내용이 없어요.',
          contentBuilder: (context) => _buildContent(context, provider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, StoryResultProvider provider) {
    final pages = provider.story!.pages;
    final pageIndex = _currentPage.clamp(0, pages.length - 1);
    final page = pages[pageIndex];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: page.imageUrl != null
                        ? Image.network(
                      ApiConfig.resolveMediaUrl(page.imageUrl!),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.yellowColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                      const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    )
                        : const Center(
                      child: Icon(
                        Icons.auto_stories,
                        color: Colors.white38,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: pageIndex > 0
                              ? () => _changePage(-1, pages.length)
                              : null,
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '페이지 ${pageIndex + 1} /${pages.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: pageIndex < pages.length - 1
                              ? () => _changePage(1, pages.length)
                              : null,
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isPlaying
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        page.content,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Quicksand',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: page.audioUrl != null
                              ? () => _togglePlay(page.audioUrl)
                              : null,
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(_isPlaying ? '일시정지' : '영어로 듣기 (TTS)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: provider.isTogglingFavorite
                              ? null
                              : _toggleFavorite,
                          icon: Icon(
                            provider.isFavorite
                                ? Icons.bookmark
                                : Icons.bookmark_add,
                            color: provider.isFavorite
                                ? AppTheme.yellowColor
                                : Colors.white,
                          ),
                          label: Text(
                            provider.isFavorite ? '즐겨찾기 됨' : '즐겨찾기에 담기',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),

                    if (provider.choices.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      const Text(
                        '다음에 어떤 일이 일어날까요?',
                        style: TextStyle(
                          color: AppTheme.yellowColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '🚧 선택해서 이어가는 기능은 곧 추가돼요. 지금은 살짝 보여드릴게요!',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      for (final choice in provider.choices) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
                              disabledForegroundColor: Colors.white54,
                            ),
                            child: Text(choice),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    const SizedBox(height: 32),
                    _QuizEntryCard(
                      storyId: provider.storyId,
                      isDone: _isQuizDone,
                      onStart: _openQuiz,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 동화 생성·조회가 오래 걸릴 수 있어(생성은 최대 2분 가까이) 멈춘 게 아니라는
/// 안내를 함께 보여준다. `quiz_screen.dart`의 `_QuizLoading`과 같은 자리다.
class _StoryLoading extends StatelessWidget {
  final bool isCreating;

  const _StoryLoading({required this.isCreating});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.yellowColor),
          const SizedBox(height: 20),
          Text(
            isCreating ? '마법사가 동화를 만들고 있어요...' : '동화를 불러오고 있어요...',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (isCreating) ...[
            const SizedBox(height: 8),
            const Text(
              '그림과 목소리까지 준비하느라 1~2분 정도 걸릴 수 있어요.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 동화를 읽은 뒤 퀴즈로 이어지는 진입 카드. (P-ED-QZ02)
///
/// 풀지 않고 넘어가려면 화면 위쪽의 '처음으로'를 쓰거나, 퀴즈 화면에서 '퀴즈 건너뛰기'를 누른다.
class _QuizEntryCard extends StatelessWidget {
  final int? storyId;
  final bool isDone;
  final Future<void> Function(int storyId) onStart;

  const _QuizEntryCard({
    required this.storyId,
    required this.isDone,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final id = storyId;
    final canStart = id != null && !isDone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.pastelPurple, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '동화가 재미있었나요? 퀴즈로 확인해 볼까요?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canStart ? () => onStart(id) : null,
              icon: Icon(isDone ? Icons.check_circle : Icons.quiz),
              label: Text(isDone ? '퀴즈를 마쳤어요' : '퀴즈 풀기'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white54,
              ),
            ),
          ),
          if (id == null) ...[
            const SizedBox(height: 8),
            const Text(
              '동화가 저장되면 퀴즈를 풀 수 있어요.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
