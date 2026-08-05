import 'package:flutter/material.dart';

class StoryResultScreen extends StatefulWidget {
  const StoryResultScreen({super.key});

  @override
  State<StoryResultScreen> createState() => _StoryResultScreenState();
}

class _StoryResultScreenState extends State<StoryResultScreen> {
  // TTS 재생 상태를 시뮬레이션 하기 위한 변수
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('생성 완료!'),
        actions: [
          TextButton(
            onPressed: () {
              // 처음으로 돌아가기 기능
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('처음으로', style: TextStyle(color: Color(0xFFF4DC08))),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // 태블릿 대응: 넓은 화면에서는 가로로 이미지-텍스트 배치
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // [SG04] 생성된 삽화 렌더링 영역
                // ==========================================
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      // TODO: 나중에 실제 DALL-E 생성 이미지 URL로 교체
                      image: const DecorationImage(
                        image: NetworkImage('https://picsum.photos/400/400'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // ==========================================
                // [SG04, SG05] 텍스트 및 학습 인터페이스 영역
                // ==========================================
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [SG05_LEARN_02] 문장 하이라이트 UI 시뮬레이션
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

                      // [SG05_LEARN_01, 05] TTS 및 단어장 액션 버튼
                      Row(
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
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              // [SG05_LEARN_05] 단어장 저장 로직
                            },
                            icon: const Icon(Icons.bookmark_add, color: Colors.white),
                            label: const Text('내 책장에 저장', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // ==========================================
                      // [SG04_GEN_03] 스토리 이어가기 선택지 제공 (비선형 분기)
                      // ==========================================
                      const Text(
                        '다음에 어떤 일이 일어날까요?',
                        style: TextStyle(color: Color(0xFFF4DC08), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
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