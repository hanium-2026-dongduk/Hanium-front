import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/models/story_payload.dart';
import 'package:hanium_front/screens/quiz/quiz_screen.dart';

class StoryResultScreen extends StatefulWidget {
  final StoryCreatePayload payload;

  /// 서버에 저장된 동화의 id. 퀴즈(QZ02)는 이 값이 있어야 만들 수 있다.
  /// 동화 생성이 아직 백엔드와 연결되지 않아 지금은 넘겨주는 곳이 없다.
  final int? storyId;

  const StoryResultScreen({super.key, required this.payload, this.storyId});

  @override
  State<StoryResultScreen> createState() => _StoryResultScreenState();
}

class _StoryResultScreenState extends State<StoryResultScreen> {
  bool _isPlaying = false;
  bool _isQuizOpen = false;

  /// 퀴즈를 끝까지 풀어 채점까지 마쳤는지. 마쳤다면 다시 열지 못하게 한다.
  /// (같은 동화로 다시 열면 문항이 교체되고 포인트가 또 지급된다.)
  bool _isQuizDone = false;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('생성 완료!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('처음으로', style: TextStyle(color: AppTheme.yellowColor)),
          ),
        ],
      ),
      body: Center(
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
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        'https://picsum.photos/400/400',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.yellowColor,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isPlaying ? Colors.white.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '"The little pilot flew high in the sky. He met a tiny angel lost in the soft clouds."',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Quicksand',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '"꼬마 조종사는 하늘 높이 날아갔어요. 그는 폭신한 구름 속에서 길을 잃은 작은 천사를 만났답니다."',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isPlaying = !_isPlaying;
                              });
                            },
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            label: Text(_isPlaying ? '일시정지' : '영어로 듣기 (TTS)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              // 단어장 저장 로직
                            },
                            icon: const Icon(Icons.bookmark_add, color: Colors.white),
                            label: const Text('내 책장에 저장', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      const Text(
                        '다음에 어떤 일이 일어날까요?',
                        style: TextStyle(color: AppTheme.yellowColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                          child: const Text('천사와 함께 별을 따러 간다', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                          child: const Text('무지개 미끄럼틀을 타고 내려온다', style: TextStyle(color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 32),
                      _QuizEntryCard(
                        storyId: widget.storyId,
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

  const _QuizEntryCard({required this.storyId, required this.isDone, required this.onStart});

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
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
