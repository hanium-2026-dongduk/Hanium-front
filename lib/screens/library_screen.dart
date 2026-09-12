import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // LB01: 임시 동화 데이터 (날짜 정보 포함)
  final List<Map<String, dynamic>> _stories = [
    {'title': 'A Sweet Bedtime Story', 'date': DateTime(2026, 8, 25), 'cover': Icons.nightlight_round},
    {'title': 'The Cloud Hopper', 'date': DateTime(2026, 8, 24), 'cover': Icons.cloud},
    {'title': 'The Magical Treehouse', 'date': DateTime(2026, 8, 20), 'cover': Icons.park},
    {'title': 'The Village Project', 'date': DateTime(2026, 8, 15), 'cover': Icons.house},
    {'title': 'Rafting to a New Land', 'date': DateTime(2026, 8, 10), 'cover': Icons.sailing},
    {'title': 'My Secret Garden', 'date': DateTime(2026, 8, 5), 'cover': Icons.local_florist},
  ];

  // LB02: 정렬 상태 (기본은 최신순)
  String _sortOption = '최신순';

  @override
  Widget build(BuildContext context) {
    // LB02: 정렬 옵션에 따라 리스트 정렬
    List<Map<String, dynamic>> displayedStories = List.from(_stories);
    displayedStories.sort((a, b) {
      if (_sortOption == '최신순') {
        return b['date'].compareTo(a['date']);
      } else {
        return a['date'].compareTo(b['date']);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MY LIBRARY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}), // 와이어프레임 4번: 검색
          IconButton(icon: const Icon(Icons.favorite, color: AppTheme.pastelPink), onPressed: () {}), // 와이어프레임 3번: 즐겨찾기
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 정렬 드롭다운 (LB02)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortOption,
                        dropdownColor: AppTheme.navyColor,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'CookieRun'),
                        items: ['최신순', '오래된순'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sortOption = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 동화 목록 그리드 (LB01)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.75, // 카드 세로 비율을 조금 길게 조정 (책 표지 느낌)
                ),
                itemCount: displayedStories.length,
                itemBuilder: (context, index) {
                  final story = displayedStories[index];
                  return _buildStoryCard(story);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 컴포넌트: 정사각형 느낌의 책 카드 ---
  Widget _buildStoryCard(Map<String, dynamic> story) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 책 표지 이미지 영역 (임시로 아이콘 대체)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.pastelBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Icon(story['cover'], size: 48, color: AppTheme.navyColor.withOpacity(0.5)),
            ),
          ),

          // 제목 및 하단 버튼 영역
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(
                  story['title'],
                  style: const TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 삭제 버튼 (빨간색)
                    _buildSmallButton('삭제', Colors.redAccent, () {
                      print('삭제 팝업 띄우기');
                    }),
                    // 열기 버튼 (초록색)
                    _buildSmallButton('열기', AppTheme.pastelGreen, () {
                      print('동화 열기');
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 하단 쪼꼬미 버튼 ---
  Widget _buildSmallButton(String text, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
