@Tags(['integration'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/providers/usage_heartbeat_provider.dart';
import 'package:hanium_front/services/auth_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/usage_service.dart';
import 'package:mocktail/mocktail.dart';

/// 실제 백엔드에 heartbeat를 보내 학습 시간이 서버에 쌓이는지 확인하는 통합 테스트.
///
/// 활성 자녀가 있는 기존 계정이 필요하다. 계정 정보는 파일에 남기지 않고 실행할 때 넘긴다.
///
/// ```bash
/// flutter test test/integration/usage_heartbeat_test.dart \
///   --dart-define=RUN_INTEGRATION=true \
///   --dart-define=API_BASE_URL=http://127.0.0.1:3000/api \
///   --dart-define=TEST_EMAIL=<계정> --dart-define=TEST_PASSWORD=<비밀번호>
/// ```
const _runIntegration = bool.fromEnvironment('RUN_INTEGRATION');
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000/api',
);
const _email = String.fromEnvironment('TEST_EMAIL');
const _password = String.fromEnvironment('TEST_PASSWORD');

class _MemoryStorage extends Mock implements FlutterSecureStorage {}

void main() {
  if (!_runIntegration) {
    test('통합 테스트는 --dart-define=RUN_INTEGRATION=true 일 때만 돈다', () {
      // 서버가 없는 CI에서도 스위트가 깨지지 않도록 건너뛴다.
    }, skip: '실서버가 필요하다. 파일 상단 주석의 실행 방법 참고.');
    return;
  }

  late AuthProvider auth;
  late ActiveChildProvider activeChild;
  late UsageService usageService;

  setUp(() async {
    if (_email.isEmpty || _password.isEmpty) {
      fail('--dart-define=TEST_EMAIL, TEST_PASSWORD 가 필요하다.');
    }
    dotenv.loadFromString(envString: 'API_BASE_URL=$_baseUrl');

    final stored = <String, String>{};
    final storage = _MemoryStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => stored[call.namedArguments[#key]]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      stored[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((call) async => stored.remove(call.namedArguments[#key]));

    final tokenStorage = TokenStorage(storage: storage);
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final profileService = ProfileService(apiClient);
    usageService = UsageService(apiClient);
    auth = AuthProvider(
      authService: AuthService(apiClient),
      profileService: profileService,
      tokenStorage: tokenStorage,
    );
    activeChild = ActiveChildProvider(profileService: profileService);

    expect(
      await auth.login(email: _email, password: _password),
      isTrue,
      reason: auth.errorMessage,
    );
    await activeChild.load();
    expect(
      activeChild.childProfileId,
      isNotNull,
      reason: '활성 자녀가 있는 계정이어야 한다.',
    );
  });

  tearDown(() => dotenv.clean());

  /// 최근 7일 합계. 테스트 중 자정을 넘기지 않는다고 본다.
  Future<int> totalSeconds() async => (await usageService.fetchSummary(
    activeChild.childProfileId!,
  )).totalAccumulatedSeconds;

  test('heartbeat 두 번 사이의 경과 시간이 학습 시간으로 쌓인다', () async {
    final childId = activeChild.childProfileId!;
    await usageService.sendHeartbeat(childId);
    final before = await totalSeconds();

    await Future<void>.delayed(const Duration(seconds: 6));
    await usageService.sendHeartbeat(childId);

    final gained = await totalSeconds() - before;
    expect(gained, inInclusiveRange(5, 10));
  });

  test('provider는 앱을 쓰는 동안만 보내고, 뒤로 가면 더 쌓이지 않는다', () async {
    final heartbeat = UsageHeartbeatProvider(
      usageService: usageService,
      authProvider: auth,
      activeChildProvider: activeChild,
      interval: const Duration(seconds: 3),
    );
    addTearDown(heartbeat.dispose);

    // 시작하자마자 한 번 보내 기준점을 잡는다.
    await Future<void>.delayed(const Duration(seconds: 1));
    final start = await totalSeconds();

    await Future<void>.delayed(const Duration(seconds: 9));
    final running = await totalSeconds();
    expect(running - start, inInclusiveRange(6, 12));
    expect(heartbeat.isLimitReached, isFalse);

    heartbeat.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(seconds: 1));
    final paused = await totalSeconds();

    await Future<void>.delayed(const Duration(seconds: 6));
    expect(await totalSeconds(), paused);
    expect(heartbeat.isRunning, isFalse);
  });
}
