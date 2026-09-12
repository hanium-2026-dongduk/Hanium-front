import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  String selectedChild = '김우진 (6)';
  final List<String> childrenList = ['김우진 (6)', '김지아 (4)'];

  // ✨ 주간/월간 상태를 관리하는 변수 추가
  bool isWeeklyStats = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('보호자용 화면', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Column(
            children: [
              // 1. 자녀 프로필 선택 드롭다운
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('자녀 프로필 선택', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedChild,
                        dropdownColor: AppTheme.navyColor,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedChild = newValue;
                            });
                          }
                        },
                        items: childrenList.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppTheme.pastelBlue,
                                  child: Icon(Icons.person, size: 16, color: AppTheme.navyColor),
                                ),
                                const SizedBox(width: 10),
                                Text(value),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. 카드 3개 레이아웃
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildProfileCard(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(flex: 5, child: _buildStatsCard()),
                          const SizedBox(height: 16),
                          Expanded(flex: 4, child: _buildLogCard()),
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

  // --- 공통 카드 래퍼 ---
  Widget _buildDashboardCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // [왼쪽 전체] 자녀 프로필 정보 + 칭찬 스티커 버튼
  Widget _buildProfileCard() {
    return _buildDashboardCard(
      title: '자녀 프로필 정보',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.pastelGreen,
            child: Icon(Icons.face, size: 60, color: AppTheme.navyColor),
          ),
          const SizedBox(height: 32),
          _buildInfoRow('자녀 이름', selectedChild.split(' ')[0]),
          const SizedBox(height: 20),
          _buildInfoRow('생년월일', '2018. 05. 20'),
          const SizedBox(height: 20),
          _buildInfoRow('나이', '6세'),

          const SizedBox(height: 48), // 스티커 버튼 위 여백 확보

          // ✨ 칭찬 스티커 버튼이 프로필 쪽으로 이사 옴!
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.star, color: AppTheme.yellowColor),
              label: const Text('칭찬 스티커 발송', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navyColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // [오른쪽 위] 자녀 학습 현황 조회 (주간/월간 토글 적용)
  Widget _buildStatsCard() {
    // 탭 상태에 따라 그래프 x축 라벨과 높이(데이터)가 달라짐
    final List<String> xLabels = isWeeklyStats
        ? ['일', '월', '화', '수', '목', '금', '토']
        : ['1주차', '2주차', '3주차', '4주차'];

    // ✨ 월간 데이터의 110.0을 100.0으로 낮춰서 오버플로우 방지
    final List<double> dummyHeights = isWeeklyStats
        ? [30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 100.0]
        : [50.0, 90.0, 70.0, 100.0];

    return _buildDashboardCard(
      title: '🕒 자녀 학습 현황 조회',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  isWeeklyStats ? '주간 학습 시간 (최근 7일)' : '월간 학습 시간 (최근 4주)',
                  style: const TextStyle(color: Colors.white70)
              ),
              Row(
                children: [
                  _buildTabButton('주간', isWeeklyStats, () => setState(() => isWeeklyStats = true)),
                  const SizedBox(width: 8),
                  _buildTabButton('월간', !isWeeklyStats, () => setState(() => isWeeklyStats = false)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // ✨ 전체 박스 높이를 140으로 넉넉하게 늘려서 안정성 확보
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(xLabels.length, (index) {
                bool isLast = index == xLabels.length - 1;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: dummyHeights[index],
                      decoration: BoxDecoration(
                        color: isLast ? AppTheme.yellowColor : AppTheme.pastelGreen,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(xLabels[index], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatBadge('완료한 동화: 2권', AppTheme.pastelGreen),
              _buildStatBadge('시작한 동화: 5권', AppTheme.pastelBlue),
            ],
          )
        ],
      ),
    );
  }

  // 커스텀 탭 버튼 위젯
  Widget _buildTabButton(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.pastelGreen.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.pastelGreen : Colors.white24),
        ),
        child: Text(
            title,
            style: TextStyle(
                color: isSelected ? AppTheme.pastelGreen : Colors.white54,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            )
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // [오른쪽 아래] 최근 열람 동화 로그 (버튼 빠짐)
  Widget _buildLogCard() {
    return _buildDashboardCard(
      title: '📖 최근 자녀 열람 동화 로그 (중)',
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBookCover('슈퍼 스페이스', AppTheme.pastelBlue),
            _buildBookCover('용의 동굴 (완료)', AppTheme.pastelGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCover(String title, Color color) {
    return Column(
      children: [
        Container(
          width: 70, height: 90,
          decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
          child: const Center(child: Icon(Icons.menu_book, color: AppTheme.navyColor, size: 28)),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

