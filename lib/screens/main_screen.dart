import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/screens/mission_screen.dart';
import 'package:hanium_front/screens/attendance_screen.dart';
import 'package:hanium_front/screens/voca_screen.dart';
import 'package:hanium_front/screens/reward_history_screen.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPoints());
  }

  Future<void> _refreshPoints() async {
    final childProfileId = context.read<ActiveChildProvider>().childProfileId;
    if (childProfileId == null) return;
    await context.read<RewardProvider>().refresh(childProfileId);
  }

  @override
  Widget build(BuildContext context) {
    final points = context.watch<RewardProvider>().points;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('✨ Magic Book', style: TextStyle(color: Colors.white)),
        actions: [
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RewardHistoryScreen()),
            ),
            // 알약 모양 배지 자체는 얇지만, 터치 영역은 아동 UX 기준(48dp)을
            // 만족하도록 보이지 않는 여백으로 감싼다.
            child: SizedBox(
              height: 48,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, color: AppTheme.pastelPurple, size: 22),
                      const SizedBox(width: 8),
                      Text('$points', style: const TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(child: _buildSquareCard('동화\n생성하기', Icons.auto_awesome, AppTheme.pastelBlue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSquareCard('학습하기', Icons.menu_book, AppTheme.yellowColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSquareCard('등장인물\n관리하기', Icons.groups, AppTheme.pastelPink)),
                ],
              ),
              const SizedBox(height: 40),

              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MissionScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_circle, color: AppTheme.navyColor, size: 28),
                      SizedBox(width: 10),
                      Text("Today's Mission", style: TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildActionCard('Attendance', Icons.calendar_month, Colors.white, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                      );
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard('Word Quiz', Icons.quiz_outlined, Colors.white, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VocaScreen()),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquareCard(String title, IconData icon, Color bgColor) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: bgColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
            ),
            const SizedBox(height: 16),
            Icon(icon, color: AppTheme.navyColor, size: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.navyColor, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
