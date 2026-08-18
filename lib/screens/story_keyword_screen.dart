import 'package:flutter/material.dart';
import 'story_result_screen.dart';
import 'package:hanium_front/models/story_payload.dart';

class StoryKeywordScreen extends StatefulWidget {
  final StoryCreatePayload payload; // ✨ 상자 하나만 받기!

  const StoryKeywordScreen({super.key, required this.payload}); // 생성자 수정

  @override
  State<StoryKeywordScreen> createState() => _StoryKeywordScreenState();
}

class _StoryKeywordScreenState extends State<StoryKeywordScreen> {
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
        title: const Text('STEP 2: 상세 스토리 입력'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이전 단계에서 선택한 내용 표시
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFF4DC08)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '선택한 배경: ${widget.payload.location}\n선택한 사건: ${widget.payload.event}',
                          style: const TextStyle(color: Colors.white70, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  '어떤 이야기를 만들어볼까요?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  '팁: "공룡과 친구가 되는 이야기"처럼 짧게 써도 좋아요!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keywordController,
                  maxLength: 100,
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
                      // ✨ 마지막 키워드 데이터까지 상자에 담기
                      widget.payload.keyword = _keywordController.text;

                      // 나중에 여기서 백엔드 API로 widget.payload.toJson()을 보내게 될 거야!

                      // 결과 화면으로 꽉 찬 상자 들고 이동!
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryResultScreen(payload: widget.payload),
                        ),
                      );
                    },
                    child: const Text(
                      '✨ 동화 마법 부리기',
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
}