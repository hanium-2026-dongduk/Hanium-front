import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/child_profile.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/async_state_view.dart';
import 'learning_stats_screen.dart';
import 'received_stickers_screen.dart';
import 'reward_status_screen.dart';

/// 마이페이지 허브. 자녀 프로필(표시 전용)과 보상·학습·스티커 메뉴. (P-MY-MP01)
///
/// 프로필 수정은 보호자 PIN 흐름이 생긴 뒤에 연결하므로 여기에는 수정 버튼이 없다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final child = context.watch<ActiveChildProvider>().activeChild;
    final email = context.watch<AuthProvider>().user?.email;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '마이페이지',
          style: TextStyle(color: AppTheme.yellowColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: child == null
            ? const CenteredMessage(message: '먼저 자녀 프로필을 선택해 주세요.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileCard(child: child, guardianEmail: email),
                  const SizedBox(height: 24),
                  _MenuTile(
                    icon: Icons.emoji_events,
                    label: '보상 현황',
                    onTap: () => _open(context, const RewardStatusScreen()),
                  ),
                  const SizedBox(height: 12),
                  _MenuTile(
                    icon: Icons.bar_chart,
                    label: '학습 통계',
                    onTap: () => _open(context, const LearningStatsScreen()),
                  ),
                  const SizedBox(height: 12),
                  _MenuTile(
                    icon: Icons.favorite,
                    label: '칭찬 스티커',
                    onTap: () => _open(context, const ReceivedStickersScreen()),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ChildProfile child;
  final String? guardianEmail;

  const _ProfileCard({required this.child, required this.guardianEmail});

  @override
  Widget build(BuildContext context) {
    final imageUrl = child.profileImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final age = child.age;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.pastelPurple,
            foregroundImage: hasImage ? NetworkImage(imageUrl) : null,
            // 이미지를 불러오지 못하면 아래 기본 아이콘이 그대로 보인다.
            onForegroundImageError: hasImage ? (_, _) {} : null,
            child: const Icon(Icons.face, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.childName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [if (age != null) '$age살', child.learningLevel.label].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                if (guardianEmail != null && guardianEmail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '보호자 $guardianEmail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.yellowColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
