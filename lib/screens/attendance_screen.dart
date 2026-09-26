import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_month.dart';
import '../providers/active_child_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/reward_provider.dart';
import '../theme/theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/reward_celebration.dart';

/// 출석 현황 화면. (P-GM-RW02 연속 학습 보상)
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  int? get _childProfileId => context.read<ActiveChildProvider>().childProfileId;

  Future<void> _load() async {
    final childProfileId = _childProfileId;
    if (childProfileId == null || !mounted) return;
    final attendance = context.read<AttendanceProvider>();
    await attendance.load(childProfileId);
    if (!mounted) return;
    // 이미 보여 주던 출석 지도는 지우지 않고, 새로고침 실패만 알린다.
    final error = attendance.errorMessage;
    if (error != null && attendance.month != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _checkIn() async {
    final childProfileId = _childProfileId;
    if (childProfileId == null) return;

    final attendance = context.read<AttendanceProvider>();
    final rewardProvider = context.read<RewardProvider>();
    final result = await attendance.checkIn(childProfileId);
    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(attendance.checkInError ?? '출석 도장을 찍지 못했어요.')),
      );
      return;
    }

    // 포인트가 바뀌었을 수 있으므로 메인 화면 토큰 표시를 먼저 갱신한다.
    // 이때 레벨이 올랐는지도 함께 알 수 있어서, 축하 연출은 그 뒤에 띄운다.
    await rewardProvider.refresh(childProfileId);
    if (!mounted) return;
    final newLevel = rewardProvider.takeLevelUp();

    if (result.pointsEarned > 0 || result.badgesAwarded.isNotEmpty || newLevel != null) {
      // 연출이 닫힐 때까지 기다리지 않는다.
      unawaited(
        showRewardCelebration(
          context,
          points: result.pointsEarned,
          badgeCount: result.badgesAwarded.length,
          newLevel: newLevel,
        ),
      );
    } else if (result.alreadyChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘은 이미 출석했어요. 내일 또 만나요!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final childProfileId = context.watch<ActiveChildProvider>().childProfileId;
    // 자녀를 바꾼 직후 첫 프레임에는 Provider가 아직 이전 자녀 값을 들고 있다.
    final isCurrent = attendance.loadedChildId == childProfileId;
    final month = isCurrent ? attendance.month : null;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('출석 현황', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: childProfileId == null
            ? const CenteredMessage(message: '먼저 자녀 프로필을 선택해 주세요.')
            : RefreshIndicator(
                onRefresh: _load,
                child: AsyncStateView(
                  isLoading: (attendance.isLoading || !isCurrent) && month == null,
                  errorMessage: month == null && isCurrent ? attendance.errorMessage : null,
                  onRetry: _load,
                  isEmpty: month == null,
                  emptyMessage: '출석 정보를 불러오지 못했어요.',
                  contentBuilder: (_) => _buildContent(month!, attendance.isChecking),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(AttendanceMonth month, bool isChecking) {
    final today = DateTime.now();
    final weekDates = _thisWeekDates(today);
    final attendedSet = month.attendedDates.toSet();
    final todayKey = _dateKey(today);
    final attendedToday = attendedSet.contains(todayKey);

    final nextMilestone = StreakMilestones.nextMilestone(month.currentStreak);
    final bonusAtMilestone = nextMilestone != null ? StreakMilestones.bonusByDays[nextMilestone]! : 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Text(
            '매일매일 출석하고\n비밀 선물을 받아보세요!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  '이번 달 출석 지도 🗺️  (연속 ${month.currentStreak}일)',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final date = weekDates[i];
                    final key = _dateKey(date);
                    final isToday = key == todayKey;
                    final isAttended = attendedSet.contains(key);
                    final isFuture = date.isAfter(today);
                    return _buildStamp(
                      label: _weekdayLabels[i],
                      isToday: isToday,
                      isAttended: isAttended,
                      isFuture: isFuture,
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildAttendanceButton(attendedToday, isChecking),
          const SizedBox(height: 40),

          const Text(
            '연속 출석 보상',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.pastelPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.pastelPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: AppTheme.pastelPurple, shape: BoxShape.circle),
                  child: const Icon(Icons.redeem, color: AppTheme.navyColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextMilestone == null
                            ? '모든 연속 출석 보상을 받았어요!'
                            : '$nextMilestone일 연속 출석까지 ${nextMilestone - month.currentStreak}일 남았어요! (마법 토큰 +$bonusAtMilestone)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (nextMilestone != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (month.currentStreak / nextMilestone).clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.pastelPurple),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('현재 ${month.currentStreak}일 / $nextMilestone일', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            '이번 달 출석률 ${month.attendanceRate.toStringAsFixed(1)}%  (${month.attendedCount}/${month.denominator}일)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStamp({
    required String label,
    required bool isToday,
    required bool isAttended,
    required bool isFuture,
  }) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    if (isAttended) {
      bgColor = AppTheme.pastelGreen;
      iconColor = AppTheme.navyColor;
      icon = Icons.check_circle;
    } else if (isToday) {
      bgColor = AppTheme.yellowColor;
      iconColor = AppTheme.navyColor;
      icon = Icons.star;
    } else {
      bgColor = Colors.white.withValues(alpha: 0.1);
      iconColor = Colors.white30;
      icon = isFuture ? Icons.circle_outlined : Icons.close;
    }

    return Column(
      children: [
        Text(label, style: TextStyle(color: isToday ? AppTheme.yellowColor : Colors.white70, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ],
    );
  }

  Widget _buildAttendanceButton(bool attendedToday, bool isChecking) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: (attendedToday || isChecking) ? null : _checkIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: attendedToday ? Colors.white.withValues(alpha: 0.1) : AppTheme.yellowColor,
          foregroundColor: attendedToday ? Colors.white54 : AppTheme.navyColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: attendedToday ? 0 : 4,
        ),
        child: isChecking
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyColor),
              )
            : Text(
                attendedToday ? '오늘 출석 완료! 내일 또 만나요' : '오늘의 출석 도장 찍기',
                style: const TextStyle(fontSize: 18),
              ),
      ),
    );
  }

  List<DateTime> _thisWeekDates(DateTime today) {
    // weekday: 월=1 ... 일=7
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
