import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // 임시 출석 데이터 (0: 결석, 1: 출석완료, 2: 오늘(미출석), 3: 미래)
  final List<Map<String, dynamic>> _weeklyAttendance = [
    {'day': '월', 'status': 1},
    {'day': '화', 'status': 1},
    {'day': '수', 'status': 2}, // 오늘!
    {'day': '목', 'status': 3},
    {'day': '금', 'status': 3},
    {'day': '토', 'status': 3},
    {'day': '일', 'status': 3},
  ];

  int _totalAttendance = 12; // 이번 달 총 출석 일수

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                '매일매일 출석하고\n비밀 선물을 받아보세요!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // ==========================================
              // 1. 주간 출석 스탬프 영역
              // ==========================================
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      '이번 주 출석 지도 🗺️',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    // 요일과 스탬프를 가로로 쫙 배치
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _weeklyAttendance.map((data) => _buildStamp(data)).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ==========================================
              // 2. 출석 도장 찍기 버튼 (오늘 출석 안 했을 때만 활성화)
              // ==========================================
              _buildAttendanceButton(),
              const SizedBox(height: 40),

              // ==========================================
              // 3. 누적 출석 보상 영역
              // ==========================================
              const Text(
                '이번 달 누적 달성도',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.pastelPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.pastelPurple.withOpacity(0.3)),
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
                          const Text('다음 보상까지 3일 남았어요!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _totalAttendance / 15, // 15일 보상 기준
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.pastelPurple),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('현재 $_totalAttendance일 / 15일', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI 컴포넌트: 개별 스탬프 ---
  Widget _buildStamp(Map<String, dynamic> data) {
    String day = data['day'];
    int status = data['status'];

    Color bgColor;
    Color iconColor;
    IconData? icon;

    if (status == 1) {
      // 출석 완료
      bgColor = AppTheme.pastelGreen;
      iconColor = AppTheme.navyColor;
      icon = Icons.check_circle;
    } else if (status == 2) {
      // 오늘 (아직 출석 전)
      bgColor = AppTheme.yellowColor;
      iconColor = AppTheme.navyColor;
      icon = Icons.star;
    } else {
      // 결석(0) 이나 미래(3)
      bgColor = Colors.white.withOpacity(0.1);
      iconColor = Colors.white30;
      icon = status == 0 ? Icons.close : Icons.circle_outlined;
    }

    return Column(
      children: [
        Text(day, style: TextStyle(color: status == 2 ? AppTheme.yellowColor : Colors.white70, fontWeight: status == 2 ? FontWeight.bold : FontWeight.normal)),
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

  // --- UI 컴포넌트: 출석 도장 찍기 버튼 ---
  Widget _buildAttendanceButton() {
    // 오늘 출석을 안 한 상태(status == 2)인지 확인
    bool canAttendToday = _weeklyAttendance.any((data) => data['status'] == 2);

    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: canAttendToday
            ? () {
          setState(() {
            // 수요일(오늘)의 상태를 출석 완료(1)로 변경
            final todayIndex = _weeklyAttendance.indexWhere((data) => data['status'] == 2);
            if (todayIndex != -1) {
              _weeklyAttendance[todayIndex]['status'] = 1;
              _totalAttendance += 1;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ 출석 도장 쾅! 마법 토큰 10개를 받았어요!'),
              backgroundColor: AppTheme.pastelGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
            : null, // 이미 출석했으면 버튼 비활성화
        style: ElevatedButton.styleFrom(
          backgroundColor: canAttendToday ? AppTheme.yellowColor : Colors.white.withOpacity(0.1),
          foregroundColor: canAttendToday ? AppTheme.navyColor : Colors.white54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: canAttendToday ? 4 : 0,
        ),
        child: Text(
          canAttendToday ? '오늘의 출석 도장 찍기' : '오늘 출석 완료! 내일 또 만나요',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
