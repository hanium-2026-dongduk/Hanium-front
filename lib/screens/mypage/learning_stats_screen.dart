import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_month.dart';
import '../../models/dashboard_summary.dart';
import '../../models/usage_summary.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/learning_stats_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/async_state_view.dart';

/// 마이페이지 > 학습 통계. 이번 달 출석, 읽은 동화 수·최근 7일 학습 시간, 퀴즈 결과. (P-MY-MP03)
class LearningStatsScreen extends StatefulWidget {
  const LearningStatsScreen({super.key});

  @override
  State<LearningStatsScreen> createState() => _LearningStatsScreenState();
}

class _LearningStatsScreenState extends State<LearningStatsScreen> {
  int? _childProfileId;

  @override
  void initState() {
    super.initState();
    _childProfileId = context.read<ActiveChildProvider>().childProfileId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _childProfileId;
    if (id == null || !mounted) return;
    await context.read<LearningStatsProvider>().load(id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningStatsProvider>();
    // 자녀를 바꾼 직후 첫 프레임에는 Provider가 아직 이전 자녀 값을 들고 있다.
    final isCurrent = provider.loadedChildId == _childProfileId;
    final attendance = isCurrent ? provider.attendance : null;
    final summary = isCurrent ? provider.summary : null;
    final usage = isCurrent ? provider.usage : null;
    final hasData = attendance != null && summary != null && usage != null;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '학습 통계',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _childProfileId == null
            ? const CenteredMessage(message: '먼저 자녀 프로필을 선택해 주세요.')
            : RefreshIndicator(
                onRefresh: _load,
                child: AsyncStateView(
                  isLoading: (provider.isLoading || !isCurrent) && !hasData,
                  errorMessage: hasData || !isCurrent
                      ? null
                      : provider.errorMessage,
                  onRetry: _load,
                  isEmpty: hasData && _isEmpty(attendance, summary, usage),
                  emptyMessage: '아직 학습 기록이 없어요.\n오늘 출석하고 시작해 봐요!',
                  contentBuilder: (_) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasData) ...[
                        _AttendanceSection(month: attendance),
                        const SizedBox(height: 24),
                        _ReadingSection(
                          readStoryCount: summary.readStoryCount,
                          usage: usage,
                        ),
                        const SizedBox(height: 24),
                        _QuizSection(stats: summary.quizStats),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool _isEmpty(
    AttendanceMonth attendance,
    DashboardSummary summary,
    UsageSummary usage,
  ) =>
      attendance.attendedCount == 0 &&
      summary.readStoryCount == 0 &&
      usage.totalAccumulatedSeconds == 0 &&
      summary.quizStats.totalAttempts == 0;
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.yellowColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  final AttendanceMonth month;

  const _AttendanceSection({required this.month});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('이번 달 출석'),
        Row(
          children: [
            _StatBox(value: '${month.attendedCount}일', label: '출석 일수'),
            const SizedBox(width: 12),
            _StatBox(
              value: '${month.attendanceRate.toStringAsFixed(1)}%',
              label: '출석률',
            ),
            const SizedBox(width: 12),
            _StatBox(value: '${month.currentStreak}일', label: '연속 출석'),
          ],
        ),
      ],
    );
  }
}

class _ReadingSection extends StatelessWidget {
  final int readStoryCount;
  final UsageSummary usage;

  const _ReadingSection({required this.readStoryCount, required this.usage});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('동화와 학습 시간'),
        Row(
          children: [
            _StatBox(value: '$readStoryCount권', label: '읽은 동화'),
            const SizedBox(width: 12),
            _StatBox(
              value: _formatDuration(usage.totalAccumulatedSeconds),
              label: '최근 7일 학습',
            ),
          ],
        ),
      ],
    );
  }

  /// 분 단위로 내림해 보여준다. 1분이 안 되면 0분.
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest분';
    return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
  }
}

class _QuizSection extends StatelessWidget {
  final QuizStats stats;

  const _QuizSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final average = stats.averageScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('퀴즈'),
        if (stats.totalAttempts == 0)
          const Text(
            '아직 푼 퀴즈가 없어요.',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          )
        else
          Row(
            children: [
              _StatBox(value: '${stats.totalAttempts}번', label: '퀴즈 응시'),
              const SizedBox(width: 12),
              _StatBox(
                value: average == null ? '-' : '${_formatScore(average)}점',
                label: '평균 점수',
              ),
            ],
          ),
      ],
    );
  }

  String _formatScore(double score) => score == score.roundToDouble()
      ? score.toStringAsFixed(0)
      : score.toStringAsFixed(1);
}
