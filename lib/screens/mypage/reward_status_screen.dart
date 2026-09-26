import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/badge_status.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/reward_status_provider.dart';
import '../../theme/theme.dart';
import '../../utils/reward_icons.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/level_progress_card.dart';
import '../reward_history_screen.dart';

/// 마이페이지 > 보상 현황. 포인트·레벨·배지와 보상 내역 진입. (P-MY-MP02, P-GM-RW04)
class RewardStatusScreen extends StatefulWidget {
  const RewardStatusScreen({super.key});

  @override
  State<RewardStatusScreen> createState() => _RewardStatusScreenState();
}

class _RewardStatusScreenState extends State<RewardStatusScreen> {
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
    await context.read<RewardStatusProvider>().load(id);
  }

  void _showBadgeSheet(BadgeStatus badge) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navyColor,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeIcon(badge: badge, size: 72),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.isEarned ? badge.description : badge.condition.hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RewardStatusProvider>();
    // 자녀를 바꾼 직후 첫 프레임에는 Provider가 아직 이전 자녀 값을 들고 있다.
    final isCurrent = provider.loadedChildId == _childProfileId;
    final detail = isCurrent ? provider.detail : null;
    final badges = isCurrent ? provider.badges : null;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '보상 현황',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _childProfileId == null
            ? const CenteredMessage(message: '먼저 자녀 프로필을 선택해 주세요.')
            : RefreshIndicator(
                onRefresh: _load,
                child: AsyncStateView(
                  isLoading: (provider.isLoading || !isCurrent) && detail == null,
                  errorMessage: detail == null && isCurrent ? provider.errorMessage : null,
                  onRetry: _load,
                  contentBuilder: (_) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (detail != null) LevelProgressCard(detail: detail),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => const RewardHistoryScreen()),
                        ),
                        icon: const Icon(Icons.history, color: Colors.white),
                        label: const Text('보상 내역 보기', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '내 배지 ${badges?.earnedCount ?? 0}/${badges?.totalCount ?? 0}',
                        style: const TextStyle(
                          color: AppTheme.yellowColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (badges == null || badges.badges.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('아직 배지가 없어요.', style: TextStyle(color: Colors.white70)),
                          ),
                        )
                      else
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                          children: [
                            for (final badge in badges.badges)
                              _BadgeTile(badge: badge, onTap: () => _showBadgeSheet(badge)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final BadgeStatus badge;
  final double size;

  const _BadgeIcon({required this.badge, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = badge.isEarned ? RewardIcons.colorFor(badge.iconKey) : Colors.white24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: badge.isEarned ? 0.25 : 0.1),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        badge.isEarned ? RewardIcons.iconFor(badge.iconKey) : Icons.lock,
        color: color,
        size: size * 0.5,
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeStatus badge;
  final VoidCallback onTap;

  const _BadgeTile({required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 배경색을 InkWell 바깥 Material이 그려야 눌렀을 때 리플이 보인다.
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgeIcon(badge: badge, size: 56),
              const SizedBox(height: 8),
              Text(
                badge.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: badge.isEarned ? Colors.white : Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
