import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/screens/mission_screen.dart';
import 'package:hanium_front/screens/attendance_screen.dart';
import 'package:hanium_front/screens/voca_screen.dart';
import 'package:hanium_front/screens/reward_history_screen.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/main_dashboard_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/auth/profile_list_screen.dart';
import 'package:hanium_front/screens/library_screen.dart';
import 'package:hanium_front/screens/mypage/my_page_screen.dart';
import 'package:hanium_front/screens/story_creation_screen.dart';
import 'package:hanium_front/services/dashboard_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final MainDashboardProvider _dashboard;
  int? _observedChildId;

  @override
  void initState() {
    super.initState();
    _dashboard = MainDashboardProvider(
      service: context.read<DashboardService>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final childId = context.watch<ActiveChildProvider>().childProfileId;
    if (childId == _observedChildId) return;
    _observedChildId = childId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _observedChildId != childId) return;
      _refreshSummaryAndPoints(childId);
    });
  }

  Future<void> _refreshSummaryAndPoints(int? childId) async {
    final rewards = context.read<RewardProvider>();
    await Future.wait([
      _dashboard.load(childId),
      if (childId != null) rewards.refresh(childId),
    ]);
  }

  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (!mounted) return;
    await _refreshSummaryAndPoints(
      context.read<ActiveChildProvider>().childProfileId,
    );
  }

  /// 다른 자녀를 고르면 ActiveChildProvider가 바뀌어 didChangeDependencies에서
  /// 대시보드·포인트를 새 자녀 기준으로 다시 불러온다. 고르지 않고 돌아오면
  /// 그대로 둔다.
  Future<void> _openProfileSwitch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileListScreen(isSwitching: true),
      ),
    );
  }

  @override
  void dispose() {
    _dashboard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardProvider>();
    final childId = context.watch<ActiveChildProvider>().childProfileId;
    final points = rewards.points;
    final level = rewards.level;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '✨ Magic Book',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // 아동 UX 기준(48dp) 터치 영역을 맞춘다.
          IconButton(
            tooltip: '프로필 바꾸기',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.switch_account, color: Colors.white),
            onPressed: _openProfileSwitch,
          ),
          IconButton(
            tooltip: '마이페이지',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyPageScreen()),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RewardHistoryScreen(),
              ),
            ),
            // 알약 모양 배지 자체는 얇지만, 터치 영역은 아동 UX 기준(48dp)을
            // 만족하도록 보이지 않는 여백으로 감싼다.
            child: SizedBox(
              height: 48,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: AppTheme.yellowColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: AppTheme.navyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (level > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Lv.$level',
                          style: const TextStyle(
                            color: AppTheme.pastelPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAndRefresh(const StoryCreationScreen()),
                      borderRadius: BorderRadius.circular(24),
                      child: _buildSquareCard(
                        '동화\n생성하기',
                        Icons.auto_awesome,
                        AppTheme.pastelBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAndRefresh(const LibraryScreen()),
                      borderRadius: BorderRadius.circular(24),
                      child: _buildSquareCard(
                        '학습하기',
                        Icons.menu_book,
                        AppTheme.yellowColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      // 퀴즈를 풀고 돌아오면 대시보드 요약이 바뀌므로 다시 불러온다(#45).
                      onTap: () => _openAndRefresh(const VocaScreen()),
                      borderRadius: BorderRadius.circular(24),
                      child: _buildSquareCard(
                        '단어 퀴즈',
                        Icons.quiz_outlined,
                        AppTheme.pastelPink, // 원래 등장인물 관리하기의 분홍색
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _dashboard,
                builder: (context, _) => _buildDashboardSummary(childId),
              ),
              const SizedBox(height: 40),

              // Today's Mission 버튼
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MissionScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flag_circle,
                        color: AppTheme.navyColor,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "오늘의 미션",
                        style: TextStyle(
                          color: AppTheme.navyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 출석체크 버튼 (Today's Mission과 동일한 스타일)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: AppTheme.navyColor,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "출석 체크",
                        style: TextStyle(
                          color: AppTheme.navyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSummary(int? childId) {
    if (childId == null) return const SizedBox.shrink();
    final isCurrentChild = _dashboard.childProfileId == childId;
    final summary = isCurrentChild ? _dashboard.summary : null;
    if (summary == null) {
      if (isCurrentChild && _dashboard.errorMessage != null) {
        return Center(
          child: TextButton.icon(
            onPressed: () => _dashboard.load(childId),
            icon: const Icon(Icons.refresh),
            label: const Text('학습 현황을 불러오지 못했어요. 다시 시도'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '나의 학습 현황',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile('내 동화', '${summary.storyCount}권'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryTile('모은 단어', '${summary.vocabularyCount}개'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryTile(
                '퀴즈',
                '${summary.quizStats.totalAttempts}회',
                detail: summary.quizStats.totalAttempts > 0
                    ? '평균 ${summary.quizStats.averageScore ?? 0}점'
                    : null,
              ),
            ),
          ],
        ),
        if (_dashboard.errorMessage != null)
          TextButton.icon(
            onPressed: () => _dashboard.load(childId),
            icon: const Icon(Icons.refresh),
            label: const Text('최신 현황을 불러오지 못했어요. 다시 시도'),
          ),
      ],
    );
  }

  Widget _buildSummaryTile(String label, String value, {String? detail}) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (detail != null)
            Text(
              detail,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
        ],
      ),
    );
  }

  // 탭 처리는 호출하는 쪽이 InkWell로 감싸서 한다. 여기서 또 InkWell로 감싸면
  // 안쪽 InkWell이 탭을 먼저 먹어 바깥 onTap이 눌리지 않는다.
  Widget _buildSquareCard(String title, IconData icon, Color bgColor) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navyColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, color: AppTheme.navyColor, size: 36),
        ],
      ),
    );
  }
}
