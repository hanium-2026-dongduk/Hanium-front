import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // 스크롤 테스트를 위해 임시 동화 데이터를 12개로 넉넉하게 추가!
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
    {
      'title': 'Space Adventure',
      'date': DateTime(2026, 8, 1),
      'cover': Icons.rocket_launch,
      'isFavorite': true,
    },
    {
      'title': 'Dinosaur Friends',
      'date': DateTime(2026, 7, 28),
      'cover': Icons.pets,
      'isFavorite': false,
    },
    {
      'title': 'Ocean Explorer',
      'date': DateTime(2026, 7, 20),
      'cover': Icons.water,
      'isFavorite': false,
    },
    {
      'title': 'The Little Chef',
      'date': DateTime(2026, 7, 15),
      'cover': Icons.restaurant,
      'isFavorite': true,
    },
    {
      'title': 'Magic Train',
      'date': DateTime(2026, 7, 10),
      'cover': Icons.train,
      'isFavorite': false,
    },
    {
      'title': 'Winter Wonderland',
      'date': DateTime(2026, 7, 5),
      'cover': Icons.ac_unit,
      'isFavorite': false,
    },
  ];

  String _sortOption = '최신순';
  bool _showOnlyFavorites = false;
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
    List<Map<String, dynamic>> displayedStories = List.from(_stories);

    if (_showOnlyFavorites) {
      displayedStories = displayedStories
          .where((story) => story['isFavorite'] == true)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      displayedStories = displayedStories.where((story) {
        final title = story['title'].toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

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
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
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

            Expanded(
              child: displayedStories.isEmpty
                  ? const Center(
                      child: Text(
                        '해당하는 동화가 없습니다.',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(
                        left: 32.0,
                        right: 32.0,
                        top: 16.0,
                        bottom: 40.0,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 28,
                            mainAxisSpacing: 40,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: displayedStories.length,
                      itemBuilder: (context, index) {
                        return _buildStoryCard(displayedStories[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 컴포넌트: 책장에 꽂힌 실제 책 느낌의 카드 ---
  Widget _buildStoryCard(Map<String, dynamic> story) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(6, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 디테일: 책등(Spine) 느낌을 주는 왼쪽 세로 라인
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 14,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✨ 수정 포인트 1: 책 표지 비율(flex)을 확 늘려서 세로로 길게 만듦
              Expanded(
                flex: 2, // 표지가 하단보다 2배 더 길게 (비율 2:1)
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.pastelBlue,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        // 아이콘 크기도 표지 크기에 맞게 조금 더 키움
                        child: Icon(
                          story['cover'],
                          size: 64,
                          color: AppTheme.navyColor.withOpacity(0.5),
                        ),
                      ),
                    ),
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

              // 하단 텍스트 및 버튼 영역
              Expanded(
                flex: 1, // 상대적으로 하단 영역을 줄여서 표지가 돋보이게
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 12.0,
                    top: 8.0,
                    bottom: 12.0,
                  ),
                  child: Column(
                    children: [
                      // ✨ 수정 포인트 2: 제목을 Expanded와 Center로 감싸서 남는 공간 한가운데 예쁘게 위치시킴
                      Expanded(
                        child: Center(
                          child: Text(
                            story['title'],
                            // ✨ 수정 포인트 3: 글씨 크기를 14 -> 16으로 키우고 줄 간격 조절
                            style: const TextStyle(
                              color: AppTheme.navyColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 제목과 열기 버튼 사이 간격
                      SizedBox(
                        width: double.infinity,
                        child: _buildSmallButton(
                          '열기',
                          AppTheme.pastelGreen,
                          () {
                            print('${story['title']} 열기');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String text, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
