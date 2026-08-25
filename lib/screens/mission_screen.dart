import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  final List<Map<String, dynamic>> _missions = [
    {
      'title': '오늘의 첫 출석 도장 찍기',
      'reward': 10,
      'isCompleted': true,
      'isClaimed': false,
      'icon': Icons.calendar_month,
      'color': AppTheme.pastelGreen,
    },
    {
      'title': '새로운 동화 1편 생성하기',
      'reward': 50,
      'isCompleted': false,
      'isClaimed': false,
      'icon': Icons.auto_awesome,
      'color': AppTheme.pastelBlue,
    },
    {
      'title': '단어 퀴즈 3문제 맞추기',
      'reward': 30,
      'isCompleted': false,
      'isClaimed': false,
      'icon': Icons.quiz_outlined,
      'color': AppTheme.pastelPink,
    },
  ];

  @override
  Widget build(BuildContext context) {
    int completedCount = _missions.where((m) => m['isCompleted'] == true).length;
    double progress = completedCount / _missions.length;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('오늘의 미션', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
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
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.yellowColor),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: _missions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final mission = _missions[index];
                    return _buildMissionCard(mission, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionCard(Map<String, dynamic> mission, int index) {
    bool isCompleted = mission['isCompleted'];
    bool isClaimed = mission['isClaimed'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted && !isClaimed ? AppTheme.yellowColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: mission['color'], shape: BoxShape.circle),
            child: Icon(mission['icon'], color: AppTheme.navyColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isClaimed ? Colors.white54 : Colors.white,
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: AppTheme.pastelPurple, size: 14),
                    const SizedBox(width: 4),
                    Text('+${mission['reward']} 토큰', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          _buildMissionButton(isCompleted, isClaimed, index),
        ],
      ),
    );
  }

  Widget _buildMissionButton(bool isCompleted, bool isClaimed, int index) {
    if (isClaimed) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: Icon(Icons.check_circle, color: Colors.white30, size: 28),
      );
    } else if (isCompleted) {
      return ElevatedButton(
        onPressed: () {
          setState(() {
            _missions[index]['isClaimed'] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${_missions[index]['reward']} 토큰을 획득했어요!'),
              backgroundColor: AppTheme.yellowColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.yellowColor,
          foregroundColor: AppTheme.navyColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: const Text('보상받기', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    } else {
      return OutlinedButton(
        onPressed: () {
          print('미션하러 가기 클릭!');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('시작하기'),
      );
    }
  }
}
