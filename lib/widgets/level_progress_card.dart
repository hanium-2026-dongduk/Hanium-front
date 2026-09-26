import 'package:flutter/material.dart';

import '../models/reward_detail.dart';
import '../theme/theme.dart';

/// 포인트·레벨과 다음 레벨까지의 진행 막대를 보여주는 카드. (P-GM-RW04)
class LevelProgressCard extends StatelessWidget {
  final RewardDetail detail;

  const LevelProgressCard({super.key, required this.detail});

  /// 현재 레벨 구간 안에서 얼마나 왔는지(0~1). 최고 레벨이면 가득 채운다.
  double get _ratio {
    final progress = detail.levelProgress;
    final next = progress?.nextLevelAt;
    if (progress == null || next == null) return 1;
    final span = next - progress.currentLevelFloor;
    if (span <= 0) return 1;
    return ((detail.points - progress.currentLevelFloor) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = detail.levelProgress?.pointsToNextLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.yellowColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Lv.${detail.level}',
                  style: const TextStyle(
                    color: AppTheme.navyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.monetization_on, color: AppTheme.yellowColor, size: 22),
              const SizedBox(width: 6),
              Text(
                '${detail.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _ratio,
              minHeight: 14,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppTheme.pastelGreen),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remaining == null ? '최고 레벨이에요! 🎉' : '다음 레벨까지 마법 토큰 $remaining개 남았어요',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
