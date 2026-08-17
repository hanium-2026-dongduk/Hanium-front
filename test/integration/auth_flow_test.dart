@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/services/auth_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:mocktail/mocktail.dart';

/// 실제로 떠 있는 백엔드에 붙어서 계약이 맞는지 확인하는 통합 테스트.
///
/// 단위 테스트는 "우리가 믿는 계약"을 검증할 뿐이라, 그 믿음 자체가 틀리면 잡지 못한다.
/// 이 테스트는 앱이 쓰는 코드(ApiClient/AuthService/ProfileService/AuthProvider)를
/// 그대로 진짜 서버에 태워서 그 믿음을 검증한다.
///
/// 기본으로는 건너뛴다. 서버를 띄운 뒤 아래처럼 실행한다.
///
/// ```bash
/// # 1) MySQL + 백엔드 기동, 인증번호를 받을 SMTP 싱크 기동
/// # 2) 실행
/// flutter test integration_test/auth_flow_test.dart \
///   --dart-define=RUN_INTEGRATION=true \
///   --dart-define=API_BASE_URL=http://127.0.0.1:3000/api \
///   --dart-define=MAIL_SINK_FILE=/절대/경로/last-code.txt
/// ```
///
/// [MAIL_SINK_FILE]은 백엔드가 보낸 인증번호를 받아 적어두는 파일이다.
/// 회원가입이 이메일 인증을 요구하므로 이게 없으면 가입 흐름을 끝까지 볼 수 없다.
const _runIntegration = bool.fromEnvironment('RUN_INTEGRATION');
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000/api',
);
const _mailSinkFile = String.fromEnvironment('MAIL_SINK_FILE');

/// 앱과 똑같이 보안 저장소를 쓰되, 테스트에서는 메모리 맵으로 대신한다.
/// (flutter_secure_storage는 플러그인이라 테스트 바인딩에서 MethodChannel이 없다)
class _MemoryStorage extends Mock implements FlutterSecureStorage {}

void main() {
  if (!_runIntegration) {
    test('통합 테스트는 --dart-define=RUN_INTEGRATION=true 일 때만 돈다', () {
      // 서버가 없는 CI에서도 스위트가 깨지지 않도록 건너뛴다.
    }, skip: '실서버가 필요하다. 파일 상단 주석의 실행 방법 참고.');
    return;
  }

  late Map<String, String> stored;
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late AuthService authService;
  late ProfileService profileService;

  /// 매번 새 계정을 만들어 이전 실행과 섞이지 않게 한다.
  String freshEmail() =>
      'fe-int-${DateTime.now().microsecondsSinceEpoch}@example.com';

  const password = 'Integration1!';

  setUp(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=$_baseUrl');

    stored = {};
    final storage = _MemoryStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => stored[call.namedArguments[#key]]);
    when(
      () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((call) async {
      stored[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((call) async => stored.remove(call.namedArguments[#key]));

    tokenStorage = TokenStorage(storage: storage);
    apiClient = ApiClient(tokenStorage: tokenStorage);
    authService = AuthService(apiClient);
    profileService = ProfileService(apiClient);
  });

  tearDown(() => dotenv.clean());

  /// SMTP 싱크가 적어둔 인증번호를 읽는다. 발송이 비동기라 잠깐 기다려 준다.
  Future<String> readVerificationCode(String email) async {
    if (_mailSinkFile.isEmpty) {
      fail('--dart-define=MAIL_SINK_FILE 이 필요하다.');
    }
    final file = File(_mailSinkFile);

    for (var attempt = 0; attempt < 40; attempt++) {
      if (file.existsSync()) {
        final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        // 이전 실행의 잔재를 읽지 않도록 수신자까지 확인한다.
        if ((raw['to'] as String).contains(email)) return raw['code'] as String;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    fail('$email 로 간 인증번호를 $_mailSinkFile 에서 찾지 못했다.');
  }

  /// 회원가입 3단계를 실제로 통과해 계정을 만든다.
  Future<String> signUpFreshAccount() async {
    final email = freshEmail();
    await authService.sendSignupCode(email);
    final code = await readVerificationCode(email);
    await authService.verifySignupCode(email: email, code: code);
    await authService.signup(email: email, password: password);
    return email;
  }

  group('인증 계약', () {
    test('회원가입은 이메일 인증을 거쳐야 하고, 응답에 토큰이 없다', () async {
      final email = freshEmail();

      // 인증을 건너뛰고 바로 가입하면 서버가 막아야 한다.
      await expectLater(
        authService.signup(email: email, password: password),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, '상태 코드', 403),
        ),
      );

      await authService.sendSignupCode(email);
      final code = await readVerificationCode(email);
      await authService.verifySignupCode(email: email, code: code);

      final user = await authService.signup(email: email, password: password);

      // 서버 users에는 이름 컬럼이 없고 식별자는 user_id다.
      expect(user.userId, greaterThan(0));
      expect(user.email, email);
      expect(user.role, isNotEmpty);
      expect(user.status, isNotEmpty);
      // 가입만으로는 로그인되지 않는다 — 토큰이 저장되지 않았어야 한다.
      expect(stored['access_token'], isNull);
    });

    test('이미 가입된 이메일로 인증번호를 요청하면 409다', () async {
      final email = await signUpFreshAccount();

      await expectLater(
        authService.sendSignupCode(email),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, '상태 코드', 409),
        ),
      );
    });

    test('로그인 응답의 data 봉투를 풀어 토큰과 사용자를 읽는다', () async {
      final email = await signUpFreshAccount();

      final result = await authService.login(email: email, password: password);

      expect(result.accessToken, isNotEmpty);
      expect(result.refreshToken, isNotEmpty);
      expect(result.user.email, email);
      expect(result.accessToken, isNot(result.refreshToken));
    });

    test('비밀번호가 틀리면 401이고 서버 메시지를 그대로 보여준다', () async {
      final email = await signUpFreshAccount();

      await expectLater(
        authService.login(email: email, password: 'Wrong1234!'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, '상태 코드', 401)
              .having((e) => e.message, '메시지', isNotEmpty),
        ),
      );
    });

    test('서버가 요구하는 비밀번호 정책(영문+숫자+특수문자)이 우리 Validators와 같다', () async {
      final email = freshEmail();
      await authService.sendSignupCode(email);
      final code = await readVerificationCode(email);
      await authService.verifySignupCode(email: email, code: code);

      // 길이는 충분하지만 특수문자가 없다 — 우리 Validators도 같은 이유로 막는다.
      await expectLater(
        authService.signup(email: email, password: 'abcdefg1'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, '상태 코드', 400),
        ),
      );
    });
  });

  group('토큰 회전과 401 재시도', () {
    test('만료된 액세스 토큰은 리프레시 후 원래 요청이 재시도되어 성공한다', () async {
      final email = await signUpFreshAccount();
      final result = await authService.login(email: email, password: password);
      await tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      // 액세스 토큰만 못 쓰게 만들어 서버가 401을 내도록 한다.
      stored['access_token'] = 'broken.access.token';

      // ApiClient가 알아서 리프레시하고 재시도하므로 호출부는 성공만 본다.
      final profiles = await profileService.fetchProfiles();

      expect(profiles, isEmpty);
      expect(stored['access_token'], isNot('broken.access.token'));
      // 서버는 리프레시 토큰을 항상 회전시킨다.
      expect(stored['refresh_token'], isNot(result.refreshToken));
    });

    test('회전된 뒤 옛 리프레시 토큰은 재사용할 수 없다', () async {
      final email = await signUpFreshAccount();
      final result = await authService.login(email: email, password: password);
      final oldRefreshToken = result.refreshToken;

      // 한 번 갱신해서 토큰을 회전시킨다.
      final refreshed = await Dio().post<Map<String, dynamic>>(
        '$_baseUrl/auth/refresh',
        data: {'refreshToken': oldRefreshToken},
      );
      expect(refreshed.statusCode, 200);

      // 폐기된 옛 토큰으로 다시 갱신하면 거부돼야 한다.
      await expectLater(
        Dio().post<Map<String, dynamic>>(
          '$_baseUrl/auth/refresh',
          data: {'refreshToken': oldRefreshToken},
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            '상태 코드',
            401,
          ),
        ),
      );
    });

    test('리프레시까지 실패하면 토큰을 지우고 세션 만료를 알린다', () async {
      var expired = 0;
      apiClient.onSessionExpired = () async => expired++;
      await tokenStorage.saveTokens(
        accessToken: 'broken.access.token',
        refreshToken: 'broken.refresh.token',
      );

      await expectLater(
        profileService.fetchProfiles(),
        throwsA(isA<ApiException>()),
      );

      expect(stored['access_token'], isNull);
      expect(stored['refresh_token'], isNull);
      expect(expired, 1);
    });
  });

  group('자녀 프로필 계약', () {
    /// 프로필 API는 인증이 필요하므로 로그인부터 한다.
    Future<void> loginFresh() async {
      final email = await signUpFreshAccount();
      final result = await authService.login(email: email, password: password);
      await tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    }

    test('생성한 프로필의 필드가 우리 모델과 정확히 맞는다', () async {
      await loginFresh();

      final created = await profileService.createProfile(
        const ChildProfile(
          childProfileId: 0,
          childName: '첫째',
          age: 7,
          learningLevel: LearningLevel.intermediate,
        ),
      );

      expect(created.childProfileId, greaterThan(0));
      expect(created.childName, '첫째');
      expect(created.age, 7);
      expect(created.learningLevel, LearningLevel.intermediate);
      // 첫 프로필은 서버가 자동으로 활성으로 만든다.
      expect(created.isActive, isTrue);
    });

    test('수정은 PUT으로 나가고 바뀐 값이 반영된다', () async {
      await loginFresh();
      final created = await profileService.createProfile(
        const ChildProfile(childProfileId: 0, childName: '첫째', age: 7),
      );

      final updated = await profileService.updateProfile(
        created.copyWith(childName: '수정된이름', age: 9),
      );

      expect(updated.childProfileId, created.childProfileId);
      expect(updated.childName, '수정된이름');
      expect(updated.age, 9);
    });

    test('목록은 data.profiles에서 읽고 생성한 만큼 돌아온다', () async {
      await loginFresh();
      await profileService.createProfile(
        const ChildProfile(childProfileId: 0, childName: '첫째'),
      );
      await profileService.createProfile(
        const ChildProfile(childProfileId: 0, childName: '둘째'),
      );

      final profiles = await profileService.fetchProfiles();

      expect(profiles.map((p) => p.childName), containsAll(['첫째', '둘째']));
      // 활성은 보호자당 최대 1개다.
      expect(profiles.where((p) => p.isActive).length, 1);
    });

    test('두 번째 프로필은 비활성으로 생기고 activate로 전환된다', () async {
      await loginFresh();
      final first = await profileService.createProfile(
        const ChildProfile(childProfileId: 0, childName: '첫째'),
      );
      final second = await profileService.createProfile(
        const ChildProfile(childProfileId: 0, childName: '둘째'),
      );

      expect(first.isActive, isTrue);
      expect(second.isActive, isFalse);

      final activated = await profileService.activateProfile(
        second.childProfileId,
      );
      expect(activated.isActive, isTrue);

      // 전환하면 이전 활성 프로필은 자동으로 내려가야 한다.
      final profiles = await profileService.fetchProfiles();
      expect(profiles.where((p) => p.isActive).length, 1);
      expect(
        profiles.firstWhere((p) => p.isActive).childProfileId,
        second.childProfileId,
      );
    });

    test('삭제하면 목록에서 사라진다', () async {
      await loginFresh();
      final created = await profileService.createProfile(
        const ChildProfile(childProfileId: 0, childName: '삭제될아이'),
      );

      await profileService.deleteProfile(created.childProfileId);

      final profiles = await profileService.fetchProfiles();
      expect(
        profiles.map((p) => p.childProfileId),
        isNot(contains(created.childProfileId)),
      );
    });

    test('토큰 없이 프로필을 조회하면 401이다', () async {
      await expectLater(
        profileService.fetchProfiles(),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, '401 여부', isTrue),
        ),
      );
    });
  });

  group('AuthProvider 흐름', () {
    test('가입하면 토큰이 없어도 곧바로 로그인 상태가 된다', () async {
      final provider = AuthProvider(
        authService: authService,
        profileService: profileService,
        tokenStorage: tokenStorage,
      );
      final email = freshEmail();

      expect(await provider.sendSignupCode(email), isTrue);
      final code = await readVerificationCode(email);
      expect(
        await provider.verifySignupCode(email: email, code: code),
        isTrue,
      );

      // 서버는 가입 응답에 토큰을 주지 않는다. Provider가 로그인까지 이어 붙여야 한다.
      expect(await provider.signup(email: email, password: password), isTrue);

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user?.email, email);
      expect(stored['access_token'], isNotNull);
      expect(stored['user'], isNotNull);
    });

    test('앱을 다시 켜면 저장된 세션으로 로그인 상태가 복원된다', () async {
      final email = await signUpFreshAccount();
      final first = AuthProvider(
        authService: authService,
        profileService: profileService,
        tokenStorage: tokenStorage,
      );
      await first.login(email: email, password: password);

      // 같은 저장소를 쓰는 새 Provider = 앱 재시작.
      final restarted = AuthProvider(
        authService: authService,
        profileService: profileService,
        tokenStorage: tokenStorage,
      );
      await restarted.bootstrap();

      expect(restarted.status, AuthStatus.authenticated);
      expect(restarted.user?.email, email);
    });

    test('로그아웃하면 서버가 리프레시 토큰을 폐기해 재사용할 수 없다', () async {
      final email = await signUpFreshAccount();
      final provider = AuthProvider(
        authService: authService,
        profileService: profileService,
        tokenStorage: tokenStorage,
      );
      await provider.login(email: email, password: password);
      final refreshToken = stored['refresh_token']!;

      await provider.logout();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(stored['access_token'], isNull);
      await expectLater(
        Dio().post<Map<String, dynamic>>(
          '$_baseUrl/auth/refresh',
          data: {'refreshToken': refreshToken},
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
