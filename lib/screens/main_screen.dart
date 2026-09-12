import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/screens/mission_screen.dart';
import 'package:hanium_front/screens/attendance_screen.dart';
import 'package:hanium_front/screens/voca_screen.dart';
import 'package:hanium_front/screens/library_screen.dart';
import 'package:hanium_front/screens/my_page_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('✨ Magic Book', style: TextStyle(color: Colors.white)),
        actions: [
          // 마이페이지 진입 버튼 추가
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyPageScreen()),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.favorite, color: AppTheme.pastelPurple, size: 22),
                SizedBox(width: 8),
                Text('120', style: TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
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

                  // 노란색 학습하기 버튼
                  Expanded(
                    // 클릭 이벤트 추가
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LibraryScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: _buildSquareCard('학습하기', Icons.menu_book, AppTheme.yellowColor),
                    ),
                  ),

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
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
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
