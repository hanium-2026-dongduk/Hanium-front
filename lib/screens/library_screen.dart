import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<Map<String, dynamic>> _stories = [
    {'id': '1', 'title': 'A Sweet Bedtime Story', 'date': DateTime(2026, 8, 25), 'cover': Icons.nightlight_round, 'isFavorite': false},
    {'id': '2', 'title': 'The Cloud Hopper', 'date': DateTime(2026, 8, 24), 'cover': Icons.cloud, 'isFavorite': true},
    {'id': '3', 'title': 'The Magical Treehouse', 'date': DateTime(2026, 8, 20), 'cover': Icons.park, 'isFavorite': false},
    {'id': '4', 'title': 'The Village Project', 'date': DateTime(2026, 8, 15), 'cover': Icons.house, 'isFavorite': false},
    {'id': '5', 'title': 'Rafting to a New Land', 'date': DateTime(2026, 8, 10), 'cover': Icons.sailing, 'isFavorite': true},
    {'id': '6', 'title': 'My Secret Garden', 'date': DateTime(2026, 8, 5), 'cover': Icons.local_florist, 'isFavorite': false},
    {'id': '7', 'title': 'Space Adventure', 'date': DateTime(2026, 8, 1), 'cover': Icons.rocket_launch, 'isFavorite': true},
    {'id': '8', 'title': 'Dinosaur Friends', 'date': DateTime(2026, 7, 28), 'cover': Icons.pets, 'isFavorite': false},
    {'id': '9', 'title': 'Ocean Explorer', 'date': DateTime(2026, 7, 20), 'cover': Icons.water, 'isFavorite': false},
    {'id': '10', 'title': 'The Little Chef', 'date': DateTime(2026, 7, 15), 'cover': Icons.restaurant, 'isFavorite': true},
    {'id': '11', 'title': 'Magic Train', 'date': DateTime(2026, 7, 10), 'cover': Icons.train, 'isFavorite': false},
    {'id': '12', 'title': 'Winter Wonderland', 'date': DateTime(2026, 7, 5), 'cover': Icons.ac_unit, 'isFavorite': false},
  ];

  String _sortOption = '최신순';
  bool _showOnlyFavorites = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ✨ 삭제 모드 상태 변수 추가
  bool _isDeleteMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 삭제 확인 팝업 메서드
  void _showDeleteConfirmDialog(Map<String, dynamic> story) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('동화 삭제', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyColor)),
          content: Text('\'${story['title']}\'를 라이브러리에서 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.',
              style: const TextStyle(fontSize: 14, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                setState(() {
                  _stories.removeWhere((element) => element['id'] == story['id']);
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('동화가 삭제되었습니다.'), duration: Duration(seconds: 2)),
                );
              },
              child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayedStories = List.from(_stories);

    if (_showOnlyFavorites) {
      displayedStories = displayedStories.where((story) => story['isFavorite'] == true).toList();
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
            : const Text('MY LIBRARY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          // 삭제 모드 토글 버튼
          IconButton(
            icon: Icon(
              _isDeleteMode ? Icons.delete_forever : Icons.delete_outline,
              color: _isDeleteMode ? Colors.redAccent : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isDeleteMode = !_isDeleteMode;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 삭제 모드 활성화 시 안내 텍스트
                  _isDeleteMode
                      ? const Text('삭제할 동화를 선택하세요.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                      : const SizedBox.shrink(),
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
            Expanded(
              child: displayedStories.isEmpty
                  ? const Center(
                child: Text('해당하는 동화가 없습니다.', style: TextStyle(color: Colors.white54, fontSize: 16)),
              )
                  : GridView.builder(
                padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 16.0, bottom: 40.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(6, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 14,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.pastelBlue,
                        borderRadius: BorderRadius.only(topRight: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Icon(story['cover'], size: 64, color: AppTheme.navyColor.withOpacity(0.5)),
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: IconButton(
                        icon: Icon(
                          story['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                          color: story['isFavorite'] ? AppTheme.pastelPink : Colors.white,
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
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 12.0, top: 8.0, bottom: 12.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            story['title'],
                            style: const TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ✨ 삭제 모드 상태에 따라 하단 버튼 동적 변경
                      SizedBox(
                        width: double.infinity,
                        child: _isDeleteMode
                            ? _buildSmallButton('삭제', Colors.redAccent, () => _showDeleteConfirmDialog(story))
                            : _buildSmallButton('열기', AppTheme.pastelGreen, () => print('${story['title']} 열기')),
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
            BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
