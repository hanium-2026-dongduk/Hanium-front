import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_month.dart';
import '../../models/dashboard_summary.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/learning_stats_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/async_state_view.dart';

/// 마이페이지 > 학습 통계. 이번 달 출석과 퀴즈 결과. (P-MY-MP03)
///
/// 읽은 동화 수·학습 시간은 서버 집계(BE-C)가 준비되면 채운다.
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
    if (id == null) return;
    await context.read<LearningStatsProvider>().load(id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningStatsProvider>();
    final attendance = provider.attendance;
    final summary = provider.summary;
    final hasData = attendance != null && summary != null;

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
                  isLoading: provider.isLoading && !hasData,
                  errorMessage: hasData ? null : provider.errorMessage,
                  onRetry: _load,
                  isEmpty: hasData && _isEmpty(attendance, summary),
                  emptyMessage: '아직 학습 기록이 없어요.\n오늘 출석하고 시작해 봐요!',
                  contentBuilder: (_) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasData) ...[
                        _AttendanceSection(month: attendance),
                        const SizedBox(height: 24),
                        _QuizSection(stats: summary.quizStats),
                        const SizedBox(height: 24),
                        const _ComingSoonCard(icon: Icons.menu_book, label: '읽은 동화'),
                        const SizedBox(height: 12),
                        const _ComingSoonCard(icon: Icons.timer, label: '학습 시간'),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool _isEmpty(AttendanceMonth attendance, DashboardSummary summary) =>
      attendance.attendedCount == 0 && summary.quizStats.totalAttempts == 0;
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
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            _StatBox(value: '${month.attendanceRate.toStringAsFixed(1)}%', label: '출석률'),
            const SizedBox(width: 12),
            _StatBox(value: '${month.currentStreak}일', label: '연속 출석'),
          ],
        ),
      ],
    );
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
          const Text('아직 푼 퀴즈가 없어요.', style: TextStyle(color: Colors.white70, fontSize: 15))
        else
          Row(
            children: [
              _StatBox(value: '${stats.totalAttempts}번', label: '퀴즈 응시'),
              const SizedBox(width: 12),
              _StatBox(value: average == null ? '-' : '${_formatScore(average)}점', label: '평균 점수'),
            ],
          ),
      ],
    );
  }

  String _formatScore(double score) =>
      score == score.roundToDouble() ? score.toStringAsFixed(0) : score.toStringAsFixed(1);
}

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoonCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 16)),
          ),
          const Text('곧 만나요', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
