import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../models/attendance_month.dart';
import '../providers/active_child_provider.dart';
import '../providers/reward_provider.dart';
import '../services/attendance_service.dart';
import '../theme/theme.dart';
import '../widgets/async_state_view.dart';

/// 출석 현황 화면. (P-GM-RW02 연속 학습 보상)
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  AttendanceMonth? _month;
  bool _isLoading = true;
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  int? get _childProfileId => context.read<ActiveChildProvider>().childProfileId;

  Future<void> _load() async {
    final childProfileId = _childProfileId;
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
      final month = await context.read<AttendanceService>().fetchMonthly(childProfileId);
      if (!mounted) return;
      setState(() {
        _month = month;
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

  /// 도장 찍기. 서버가 멱등하게 처리하므로("같은 날 몇 번 호출해도 안전"),
  /// 이미 출석한 날에도 다시 눌러 최신 상태를 다시 받아오는 것 자체는 안전하다.
  Future<void> _checkIn() async {
    final childProfileId = _childProfileId;
    if (childProfileId == null || _isChecking) return;

    setState(() => _isChecking = true);
    try {
      final result = await context.read<AttendanceService>().checkIn(childProfileId);
      await _load();
      if (!mounted) return;

      if (result.pointsEarned > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ 출석 도장 쾅! 마법 토큰 ${result.pointsEarned}개를 받았어요!'),
            backgroundColor: AppTheme.pastelGreen,
            behavior: SnackBarBehavior.floating,
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

      if (result.badgesAwarded.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏅 새 배지를 획득했어요! (${result.badgesAwarded.join(', ')})'),
            backgroundColor: AppTheme.pastelPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 포인트가 바뀌었을 수 있으므로 메인 화면 토큰 표시도 갱신한다.
      if (mounted) {
        await context.read<RewardProvider>().refresh(childProfileId);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('출석 현황', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: AsyncStateView(
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onRetry: _load,
            isEmpty: _month == null,
            emptyMessage: '출석 정보를 불러오지 못했어요.',
            contentBuilder: (_) => _buildContent(_month!),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AttendanceMonth month) {
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

          _buildAttendanceButton(attendedToday),
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
                            : '$nextMilestone일 연속 출석까지 ${nextMilestone - month.currentStreak}일 남았어요! (+$bonusAtMilestone 토큰)',
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
                        Text('현재 ${month.currentStreak}일 / $nextMilestone일', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            style: const TextStyle(color: Colors.white54, fontSize: 13),
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

  Widget _buildAttendanceButton(bool attendedToday) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: (attendedToday || _isChecking) ? null : _checkIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: attendedToday ? Colors.white.withValues(alpha: 0.1) : AppTheme.yellowColor,
          foregroundColor: attendedToday ? Colors.white54 : AppTheme.navyColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: attendedToday ? 0 : 4,
        ),
        child: _isChecking
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
