import 'package:flutter/material.dart';
import 'story_keyword_screen.dart';
import 'package:hanium_front/models/story_payload.dart';

class StorySettingScreen extends StatefulWidget {
  final StoryCreatePayload payload;

  const StorySettingScreen({super.key, required this.payload});

  @override
  State<StorySettingScreen> createState() => _StorySettingScreenState();
}

class _StorySettingScreenState extends State<StorySettingScreen> {
  String _selectedLocation = '';
  String _selectedEvent = '';

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
                const SizedBox(height: 60),

                // ==========================================
                // 다음 단계 (키워드 입력) 이동 버튼
                // ==========================================
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.payload.location = _selectedLocation;
                      widget.payload.event = _selectedEvent;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryKeywordScreen(payload: widget.payload),
                        ),
                      );
                    },
                    child: const Text(
                      '다음',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
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