import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/reward_service.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
  } catch (_) {
    // .env를 아직 안 만들었어도 앱은 뜬다. (ApiConfig가 로컬 기본값으로 떨어짐)
    debugPrint('.env를 찾지 못했어요. cp .env.example .env 로 만들어 주세요.');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final ProfileService _profileService;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();

    // 앱이 공유하는 객체들을 여기서 한 번만 만든다.
    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(tokenStorage: _tokenStorage);
    _profileService = ProfileService(_apiClient);
    _authProvider = AuthProvider(
      authService: AuthService(_apiClient),
      // 백엔드에 "내 정보" 엔드포인트가 없어서, 저장된 토큰이 아직 유효한지
      // 확인할 때 인증이 필요한 프로필 목록 API를 대신 쓴다.
      profileService: _profileService,
      tokenStorage: _tokenStorage,
    );

    // 토큰 갱신까지 실패하면 AuthProvider가 로그인 화면으로 되돌린다.
    // 서로를 참조해야 해서 생성자 대신 여기서 연결한다.
    _apiClient.onSessionExpired = _authProvider.handleSessionExpired;

    // 저장된 토큰으로 자동 로그인을 시도한다.
    _authProvider.bootstrap();
  }

  @override
  void dispose() {
    _authProvider.dispose();
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
        Provider<RewardService>(create: (_) => RewardService(_apiClient)),
      ],
      child: MaterialApp(
        title: 'Magic Book',
        theme: AppTheme.lightTheme, // theme.dart에서 정의한 테마 적용
        debugShowCheckedModeBanner: false, // 우측 상단 디버그(Debug) 띠 제거

        // 로그인 기능 테스트시 주석 해제
        // home: const AuthGate(),

        // UI 작업 위해 메인 스크린 연결
        home: const MainScreen(),
      ),
    );
  }
}
