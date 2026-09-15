import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../models/daily_mission.dart';
import '../providers/active_child_provider.dart';
import '../services/mission_service.dart';
import '../theme/theme.dart';
import '../widgets/async_state_view.dart';

/// 오늘의 미션 화면. (P-GM-RW01)
///
/// **"보상받기" 버튼은 없다.** 진행도가 목표치에 도달하는 순간 서버가 자동으로
/// 포인트를 지급한다(`API_SPEC_REWARD.md` 4절) — 화면은 진행도와 완료 여부만
/// 보여준다.
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  List<DailyMission> _missions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final childProfileId = context.read<ActiveChildProvider>().childProfileId;
    if (childProfileId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '먼저 자녀 프로필을 선택해 주세요.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 오늘자 미션 행이 없으면 이 호출이 그 자리에서 만들어 준다.
      final missions = await context.read<MissionService>().fetchProgress(childProfileId);
      if (!mounted) return;
      setState(() {
        _missions = missions;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _missions.where((m) => m.status.isDone).length;
    final progress = _missions.isEmpty ? 0.0 : completedCount / _missions.length;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('오늘의 미션', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: AsyncStateView(
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onRetry: _load,
            isEmpty: _missions.isEmpty,
            emptyMessage: '오늘의 미션을 아직 불러오지 못했어요.',
            contentBuilder: (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    '미션을 달성하고\n마법 토큰을 모아보세요!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('오늘의 달성도', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text('$completedCount / ${_missions.length}', style: const TextStyle(color: AppTheme.yellowColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.yellowColor),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _missions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => _buildMissionCard(_missions[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionCard(DailyMission mission) {
    final isDone = mission.status.isDone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppTheme.pastelGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _colorFor(mission.type), shape: BoxShape.circle),
            child: Icon(_iconFor(mission.type), color: AppTheme.navyColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.type.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDone ? Colors.white54 : Colors.white,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                if (isDone)
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: AppTheme.pastelPurple, size: 14),
                      const SizedBox(width: 4),
                      Text('+${mission.rewardPoints} 토큰 획득', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: mission.progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(_colorFor(mission.type)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mission.progressCount} / ${mission.targetCount}  ·  +${mission.rewardPoints} 토큰',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (isDone)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(Icons.check_circle, color: AppTheme.pastelGreen, size: 28),
            ),
        ],
      ),
    );
  }

  Color _colorFor(MissionType type) {
    switch (type) {
      case MissionType.attendance:
        return AppTheme.pastelGreen;
      case MissionType.storyRead:
        return AppTheme.pastelBlue;
      case MissionType.wordClicked:
        return AppTheme.pastelPurple;
      case MissionType.quizAnswered:
        return AppTheme.pastelPink;
    }
  }

  IconData _iconFor(MissionType type) {
    switch (type) {
      case MissionType.attendance:
        return Icons.calendar_month;
      case MissionType.storyRead:
        return Icons.auto_stories;
      case MissionType.wordClicked:
        return Icons.menu_book;
      case MissionType.quizAnswered:
        return Icons.quiz_outlined;
    }
  }
}
