import 'package:flutter/material.dart';
import 'story_result_screen.dart'; // 이따가 만들 결과 화면

class StorySettingScreen extends StatefulWidget {
  const StorySettingScreen({super.key});

  @override
  State<StorySettingScreen> createState() => _StorySettingScreenState();
}

class _StorySettingScreenState extends State<StorySettingScreen> {
  // --- [SG03] 스토리 설정 상태 변수 ---
  String _selectedLocation = '';
  String _selectedEvent = '';
  final TextEditingController _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STEP 1: 주제 고르기'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // [SG03_STORY_01] 스토리 배경 선택
                // ==========================================
                _buildSectionTitle('어디에서 일어날까요?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCircleSelectBtn('신비로운 숲', Icons.park, true),
                    _buildCircleSelectBtn('바다 깊은 곳', Icons.water, true),
                    _buildCircleSelectBtn('하늘 위 성', Icons.cloud, true),
                  ],
                ),
                const SizedBox(height: 40),

                // ==========================================
                // [SG03_STORY_02] 핵심 사건 선택
                // ==========================================
                _buildSectionTitle('어떤 일이 일어날까요?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCircleSelectBtn('숨겨진 보물 찾기', Icons.diamond, false),
                    _buildCircleSelectBtn('마법사 물리치기', Icons.flash_on, false),
                    _buildCircleSelectBtn('친구 구하기', Icons.people, false),
                  ],
                ),
                const SizedBox(height: 40),

                // ==========================================
                // [SG03_STORY_01, 02] 상세 스토리 키워드 직접 입력
                // ==========================================
                _buildSectionTitle('어떤 이야기를 만들어볼까요?'),
                const SizedBox(height: 8),
                const Text(
                  '팁: "공룡과 친구가 되는 이야기"처럼 짧게 써도 좋아요!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keywordController,
                  maxLength: 100, // 요구사항 반영: 최대 100자 제한
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '비행기 조종사가 된 우리 아이가 구름 나라에 가서 길을 잃은 아기 천사를 도와주는 이야기...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // ==========================================
                // 동화 마법 부리기 (결과 화면으로 이동)
                // ==========================================
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      // 다음 화면으로 넘어가기
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoryResultScreen(),
                        ),
                      );
                    },
                    child: const Text('✨ 동화 마법 부리기', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  // 동그란 선택 아이콘 버튼 (UI 정의서 반영)
  Widget _buildCircleSelectBtn(String label, IconData icon, bool isLocation) {
    bool isSelected = isLocation ? _selectedLocation == label : _selectedEvent == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isLocation) {
            _selectedLocation = label;
          } else {
            _selectedEvent = label;
          }
        });
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: isSelected ? const Color(0xFFF4DC08) : Colors.white.withOpacity(0.1),
            child: Icon(icon, size: 36, color: isSelected ? const Color(0xFF151628) : Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFF4DC08) : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}