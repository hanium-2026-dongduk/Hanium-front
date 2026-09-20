import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hanium_front/screens/auth_gate.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tutorialData = [
    {
      'title': 'AI와 함께 동화 만들기 🪄',
      'description': '메인 화면에서 \'동화 생성하기\' 버튼을 눌러보세요.\n주제와 주인공을 선택하면 AI가 우리 아이만을 위한\n세상에 단 하나뿐인 특별한 이야기를 만들어줍니다.',
      'icon': Icons.auto_fix_high,
      'color': AppTheme.pastelBlue,
    },
    {
      'title': '라이브러리와 즐겨찾기 📚',
      'description': '완성된 동화는 라이브러리 책장에 보관돼요.\n\'열기\'를 눌러 동화를 감상하고, 가장 좋아하는 동화는\n우측 상단 하트(♥)를 눌러 즐겨찾기에 추가해 보세요!',
      'icon': Icons.menu_book_rounded,
      'color': AppTheme.pastelPink,
    },
    {
      'title': '독서 기록과 학습 현황 📊',
      'description': '동화를 읽으며 배운 단어들은 단어장에 자동으로 쏙!\n보호자 대시보드에서 아이의 독서 기록과 학습 성취도를\n한눈에 확인하고 아이의 성장을 응원해 주세요.',
      'icon': Icons.dashboard_customize_rounded,
      'color': AppTheme.pastelGreen,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onFinishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _tutorialData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildPageContent(_tutorialData[index]);
              },
            ),

            if (_currentPage != _tutorialData.length - 1)
              Positioned(
                top: 16,
                right: 24,
                child: TextButton(
                  onPressed: _onFinishTutorial,
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _tutorialData.length,
                          (index) => _buildDotIndicator(index == _currentPage),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: SizedBox(
                      width: 240,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage == _tutorialData.length - 1
                              ? AppTheme.pastelPink
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (_currentPage == _tutorialData.length - 1) {
                            _onFinishTutorial();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Text(
                          _currentPage == _tutorialData.length - 1 ? '시작하기' : '다음',
                          style: TextStyle(
                            color: _currentPage == _tutorialData.length - 1 ? AppTheme.navyColor : AppTheme.navyColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: data['color'].withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data['icon'],
              size: 110,
              color: data['color'],
            ),
          ),
          const SizedBox(height: 56),
          Text(
            data['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // 설명 텍스트 줄 간격과 크기를 살짝 더 읽기 편하게 조정
          Text(
            data['description'],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDotIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 10,
      width: isActive ? 32 : 10,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
