import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // LB01: 임시 동화 데이터 (isFavorite 상태 추가)
  final List<Map<String, dynamic>> _stories = [
    {
      'title': 'A Sweet Bedtime Story',
      'date': DateTime(2026, 8, 25),
      'cover': Icons.nightlight_round,
      'isFavorite': false,
    },
    {
      'title': 'The Cloud Hopper',
      'date': DateTime(2026, 8, 24),
      'cover': Icons.cloud,
      'isFavorite': true,
    },
    {
      'title': 'The Magical Treehouse',
      'date': DateTime(2026, 8, 20),
      'cover': Icons.park,
      'isFavorite': false,
    },
    {
      'title': 'The Village Project',
      'date': DateTime(2026, 8, 15),
      'cover': Icons.house,
      'isFavorite': false,
    },
    {
      'title': 'Rafting to a New Land',
      'date': DateTime(2026, 8, 10),
      'cover': Icons.sailing,
      'isFavorite': true,
    },
    {
      'title': 'My Secret Garden',
      'date': DateTime(2026, 8, 5),
      'cover': Icons.local_florist,
      'isFavorite': false,
    },
  ];

  // 정렬 상태
  String _sortOption = '최신순';

  // 즐겨찾기 필터 상태
  bool _showOnlyFavorites = false;

  // 검색 상태 관리
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------
    // 데이터 필터링 및 정렬 파이프라인
    // ----------------------------------------------------
    List<Map<String, dynamic>> displayedStories = List.from(_stories);

    // 1. 즐겨찾기 필터
    if (_showOnlyFavorites) {
      displayedStories = displayedStories
          .where((story) => story['isFavorite'] == true)
          .toList();
    }

    // 2. 검색 필터
    if (_searchQuery.isNotEmpty) {
      displayedStories = displayedStories.where((story) {
        final title = story['title'].toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 3. 정렬
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
        // 검색 모드일 때는 TextField를, 아닐 때는 제목을 보여줌
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '동화 제목을 검색하세요...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text(
                'MY LIBRARY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 검색 버튼 토글
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = ''; // 검색 취소 시 초기화
                  _searchController.clear();
                }
              });
            },
          ),
          // 즐겨찾기 필터 버튼
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? AppTheme.pastelPink : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 정렬 드롭다운
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortOption,
                        dropdownColor: AppTheme.navyColor,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CookieRun',
                        ),
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

            // 동화 목록 그리드
            Expanded(
              child: displayedStories.isEmpty
                  ? const Center(
                      child: Text(
                        '해당하는 동화가 없습니다.',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(24.0),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.75,
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
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 책 표지 영역
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.pastelBlue,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      story['cover'],
                      size: 48,
                      color: AppTheme.navyColor.withOpacity(0.5),
                    ),
                  ),
                ),
                // 개별 동화 즐겨찾기(하트) 버튼
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(
                      story['isFavorite']
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: story['isFavorite']
                          ? AppTheme.pastelPink
                          : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        story['isFavorite'] = !story['isFavorite'];
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // 제목 및 하단 버튼 영역
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(
                  story['title'],
                  style: const TextStyle(
                    color: AppTheme.navyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSmallButton('삭제', Colors.redAccent, () {
                      print('삭제 팝업 띄우기');
                    }),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
