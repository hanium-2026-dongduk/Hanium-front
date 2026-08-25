import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class VocaScreen extends StatefulWidget {
  const VocaScreen({super.key});

  @override
  State<VocaScreen> createState() => _VocaScreenState();
}

class _VocaScreenState extends State<VocaScreen> {
  // 임시 단어 데이터
  final List<Map<String, dynamic>> _words = [
    {'en': 'Castle', 'ko': '성, 대저택', 'isMemorized': true},
    {'en': 'Magic', 'ko': '마법', 'isMemorized': false},
    {'en': 'Brave', 'ko': '용감한', 'isMemorized': false},
    {'en': 'Dragon', 'ko': '용, 드래곤', 'isMemorized': false},
    {'en': 'Fairy', 'ko': '요정', 'isMemorized': true},
  ];

  // 필터 상태 (전체보기 vs 안 외운 단어만 보기)
  bool _showOnlyUnmemorized = false;

  @override
  Widget build(BuildContext context) {
    // 필터링된 단어 리스트
    final displayedWords = _showOnlyUnmemorized
        ? _words.where((w) => w['isMemorized'] == false).toList()
        : _words;

    int memorizedCount = _words.where((w) => w['isMemorized'] == true).length;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('내 단어장', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 1. 단어장 상단 요약 카드
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.pastelBlue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppTheme.pastelBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.menu_book, color: AppTheme.navyColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('내가 모은 마법 단어들 ✨', style: TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '총 ${_words.length}개 중 $memorizedCount개 암기 완료!',
                            style: TextStyle(color: AppTheme.navyColor.withOpacity(0.7), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 2. 필터 및 정렬 옵션 (이 부분의 FilterChip 수정!)
            // ==========================================
            FilterChip(
              label: const Text('안 외운 단어만'),
              selected: _showOnlyUnmemorized,
              onSelected: (bool selected) {
                setState(() {
                  _showOnlyUnmemorized = selected;
                });
              },
              // ✨ 선택됐을 땐 노란 배경, 안 됐을 땐 네이비 배경!
              selectedColor: AppTheme.yellowColor,
              backgroundColor: AppTheme.navyColor,
              labelStyle: TextStyle(
                // 글씨 색상도 배경에 맞춰 반전
                color: _showOnlyUnmemorized ? AppTheme.navyColor : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              checkmarkColor: AppTheme.navyColor,
              // 선택 안 됐을 때만 얇은 하얀색 테두리 표시
              side: BorderSide(
                color: _showOnlyUnmemorized ? Colors.transparent : Colors.white54,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 3. 단어 플래시 카드 리스트
            // ==========================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                itemCount: displayedWords.length,
                itemBuilder: (context, index) {
                  final word = displayedWords[index];
                  // 원본 리스트(_words)에서의 진짜 인덱스를 찾아서 업데이트해야 함
                  final realIndex = _words.indexOf(word);
                  return _buildWordCard(word, realIndex);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 컴포넌트: 개별 단어 카드 ---
  Widget _buildWordCard(Map<String, dynamic> word, int index) {
    bool isMemorized = word['isMemorized'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // 다 외운 단어는 테두리에 초록색 표시
          color: isMemorized ? AppTheme.pastelGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // 스피커 아이콘 (나중에 TTS 발음 듣기 기능 연결)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.volume_up, color: Colors.white70, size: 24),
          ),
          const SizedBox(width: 16),

          // 단어 (영어 & 뜻)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word['en'],
                  style: const TextStyle(color: AppTheme.yellowColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Quicksand'),
                ),
                const SizedBox(height: 4),
                Text(
                  word['ko'],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          // 암기 완료 체크 버튼
          IconButton(
            onPressed: () {
              setState(() {
                _words[index]['isMemorized'] = !isMemorized;
              });
            },
            icon: Icon(
              isMemorized ? Icons.check_circle : Icons.check_circle_outline,
              color: isMemorized ? AppTheme.pastelGreen : Colors.white30,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
