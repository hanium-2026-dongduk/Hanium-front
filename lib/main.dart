import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'providers/active_child_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/learning_stats_provider.dart';
import 'providers/received_sticker_provider.dart';
import 'providers/reward_provider.dart';
import 'providers/reward_status_provider.dart';
import 'screens/auth_gate.dart';
import 'services/attendance_service.dart';
import 'services/auth_service.dart';
import 'services/badge_service.dart';
import 'services/dashboard_service.dart';
import 'services/mission_service.dart';
import 'services/profile_service.dart';
import 'services/reward_service.dart';
import 'services/sticker_service.dart';
import 'services/tts_service.dart';
import 'services/vocabulary_service.dart';
import 'theme/theme.dart';
import 'screens/tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
  } catch (_) {
    debugPrint('.env를 찾지 못했어요.');
  }

  // 첫 실행인지 검사 (메모 없으면 true(처음)로 간주)
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  // MyApp에 검사 결과를 전달하면서 실행
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatefulWidget {
  final bool isFirstLaunch;

  const MyApp({super.key, required this.isFirstLaunch});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final ProfileService _profileService;
  late final RewardService _rewardService;
  late final AuthProvider _authProvider;
  late final ActiveChildProvider _activeChildProvider;
  late final RewardProvider _rewardProvider;
  late final TtsService _ttsService;

  @override
  void initState() {
    super.initState();

    // 앱이 공유하는 객체들을 여기서 한 번만 만든다.
    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(tokenStorage: _tokenStorage);
    _profileService = ProfileService(_apiClient);
    _rewardService = RewardService(_apiClient);
    _authProvider = AuthProvider(
      authService: AuthService(_apiClient),
      // 백엔드에 "내 정보" 엔드포인트가 없어서, 저장된 토큰이 아직 유효한지
      // 확인할 때 인증이 필요한 프로필 목록 API를 대신 쓴다.
      profileService: _profileService,
      tokenStorage: _tokenStorage,
    );
    _activeChildProvider = ActiveChildProvider(profileService: _profileService);
    _rewardProvider = RewardProvider(rewardService: _rewardService);
    _ttsService = TtsService();

    // 토큰 갱신까지 실패하면 AuthProvider가 로그인 화면으로 되돌린다.
    // 서로를 참조해야 해서 생성자 대신 여기서 연결한다.
    _apiClient.onSessionExpired = _authProvider.handleSessionExpired;

    // 저장된 토큰으로 자동 로그인을 시도한다.
    _authProvider.bootstrap();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _activeChildProvider.dispose();
    _rewardProvider.dispose();
    // 재생 중인 발음이 있다면 화면이 사라질 때 멈춘다.
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 새 기능의 Service를 추가할 때는 여기에 한 줄씩 등록하면 된다.
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        Provider<ProfileService>.value(value: _profileService),
        Provider<RewardService>.value(value: _rewardService),
        Provider<VocabularyService>(create: (_) => VocabularyService(_apiClient)),
        Provider<MissionService>(create: (_) => MissionService(_apiClient)),
        Provider<AttendanceService>(create: (_) => AttendanceService(_apiClient)),
        Provider<TtsService>.value(value: _ttsService),
        ChangeNotifierProvider<ActiveChildProvider>.value(value: _activeChildProvider),
        ChangeNotifierProvider<RewardProvider>.value(value: _rewardProvider),
        Provider<BadgeService>(create: (_) => BadgeService(_apiClient)),
        // 보상 현황 화면(MP02) 전용. 화면을 열 때마다 새로 불러온다.
        ChangeNotifierProvider<RewardStatusProvider>(
          create: (context) => RewardStatusProvider(
            rewardService: _rewardService,
            badgeService: context.read<BadgeService>(),
          ),
        ),
        Provider<DashboardService>(create: (_) => DashboardService(_apiClient)),
        Provider<StickerService>(create: (_) => StickerService(_apiClient)),
        // 학습 통계(MP03)·받은 스티커(MP05) 화면 전용. 화면을 열 때마다 새로 불러온다.
        ChangeNotifierProvider<LearningStatsProvider>(
          create: (context) => LearningStatsProvider(
            attendanceService: context.read<AttendanceService>(),
            dashboardService: context.read<DashboardService>(),
          ),
        ),
        ChangeNotifierProvider<ReceivedStickerProvider>(
          create: (context) =>
              ReceivedStickerProvider(stickerService: context.read<StickerService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Magic Book',
        theme: AppTheme.lightTheme, // theme.dart에서 정의한 테마 적용
        debugShowCheckedModeBanner: false, // 우측 상단 디버그(Debug) 띠 제거
        // 로그인 → 자녀 프로필 선택을 거쳐야 child_profile_id가 필요한 단어장/보상
        // API를 부를 수 있다. (ProfileListScreen에서 프로필을 고르면 MainScreen으로 이동)
        home: widget.isFirstLaunch ? const TutorialScreen() : const AuthGate(),
      ),
    );
  }
}
