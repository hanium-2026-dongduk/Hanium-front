import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 포인트·배지·레벨업을 얻었을 때 띄우는 축하 연출. (P-GM-RW05)
///
/// 별이 사방으로 퍼지고 획득 포인트가 올라가는 짧은 애니메이션이다.
/// 화면을 누르거나 잠시 지나면 저절로 닫힌다. 외부 패키지 없이 만든다.
Future<void> showRewardCelebration(
  BuildContext context, {
  int points = 0,
  int badgeCount = 0,
  int? newLevel,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) =>
        RewardCelebration(points: points, badgeCount: badgeCount, newLevel: newLevel),
  );
}

class RewardCelebration extends StatefulWidget {
  final int points;
  final int badgeCount;
  final int? newLevel;

  /// 이 시간이 지나면 저절로 닫힌다.
  final Duration autoCloseAfter;

  const RewardCelebration({
    super.key,
    this.points = 0,
    this.badgeCount = 0,
    this.newLevel,
    this.autoCloseAfter = const Duration(milliseconds: 2500),
  });

  @override
  State<RewardCelebration> createState() => _RewardCelebrationState();
}

class _RewardCelebrationState extends State<RewardCelebration> with SingleTickerProviderStateMixin {
  static const _starCount = 10;

  late final AnimationController _controller;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _closeTimer = Timer(widget.autoCloseAfter, _close);
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOutBack.transform(_controller.value.clamp(0.0, 1.0));
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < _starCount; i++) _buildStar(i, _controller.value),
                  Transform.scale(scale: t, child: _buildCard()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStar(int index, double progress) {
    final angle = 2 * math.pi * index / _starCount;
    final distance = 150 * Curves.easeOut.transform(progress);
    final colors = [AppTheme.yellowColor, AppTheme.pastelPink, AppTheme.pastelBlue];
    return Transform.translate(
      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
      child: Opacity(
        opacity: (1 - progress).clamp(0.0, 1.0),
        child: Icon(Icons.star, color: colors[index % colors.length], size: 28),
      ),
    );
  }

  Widget _buildCard() {
    final shownPoints = (widget.points * _controller.value).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: AppTheme.navyColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.yellowColor, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.yellowColor, size: 56),
          const SizedBox(height: 12),
          if (widget.newLevel != null) ...[
            Text(
              '레벨 업! Lv.${widget.newLevel}',
              style: const TextStyle(
                color: AppTheme.yellowColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.points > 0)
            Text(
              '+$shownPoints',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (widget.points > 0)
            Text(
              '마법 토큰 ${widget.points}개를 받았어요!',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          if (widget.badgeCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '🏅 새 배지 ${widget.badgeCount}개를 얻었어요!',
              style: const TextStyle(color: AppTheme.pastelPurple, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }
}
