import 'package:flutter/material.dart';
import 'package:hanium_front/models/story_payload.dart';

class StoryResultScreen extends StatefulWidget {
  final StoryCreatePayload payload; // ✨ 최종 전달받은 상자

  const StoryResultScreen({super.key, required this.payload}); // 생성자 수정

  @override
  State<StoryResultScreen> createState() => _StoryResultScreenState();
}

class _StoryResultScreenState extends State<StoryResultScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('생성 완료!'),
        actions: [
          TextButton(
            onPressed: () {
              // 처음으로 돌아가기 기능 (모든 화면을 끄고 첫 화면으로)
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('처음으로', style: TextStyle(color: Color(0xFFF4DC08))),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          // 에러 방지: 높이가 넘쳐도 스크롤되도록 감싸주기
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: NetworkImage('https://picsum.photos/400/400'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isPlaying ? Colors.white.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '"The little pilot flew high in the sky. He met a tiny angel lost in the soft clouds."',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Quicksand',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '"꼬마 조종사는 하늘 높이 날아갔어요. 그는 폭신한 구름 속에서 길을 잃은 작은 천사를 만났답니다."',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      // Wrap 사용으로 좁은 화면에서는 버튼이 밑으로 떨어지도록 함
                      Wrap(
                        spacing: 16, // 버튼 사이 가로 여백
                        runSpacing: 12, // 줄바꿈 시 세로 여백
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isPlaying = !_isPlaying;
                              });
                            },
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            label: Text(_isPlaying ? '일시정지' : '영어로 듣기 (TTS)'),
                          ),
                          // Wrap을 쓰면 SizedBox로 여백을 주지 않아도 spacing 속성이 알아서 띄워줘!
                          OutlinedButton.icon(
                            onPressed: () {
                              // 단어장 저장 로직
                            },
                            icon: const Icon(Icons.bookmark_add, color: Colors.white),
                            label: const Text('내 책장에 저장', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      const Text(
                        '다음에 어떤 일이 일어날까요?',
                        style: TextStyle(color: Color(0xFFF4DC08), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                          child: const Text('천사와 함께 별을 따러 간다', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                          child: const Text('무지개 미끄럼틀을 타고 내려온다', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
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
