@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/screens/auth/login_screen.dart';
import 'package:hanium_front/screens/auth/password_reset_screen.dart';
import 'package:hanium_front/screens/auth/profile_list_screen.dart';
import 'package:hanium_front/screens/auth/signup_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_provider.dart';

/// 화면을 PNG로 뽑아 눈으로 확인할 수 있게 한다.
///
/// 에뮬레이터 없이 레이아웃과 문구를 훑어보기 위한 것이라, 통과/실패를 따지는
/// 테스트가 아니다. 기본 실행에서는 건너뛰고 아래처럼 명시할 때만 돈다.
///
/// ```bash
/// flutter test test/screens/screenshot_test.dart --dart-define=SCREENSHOT=true
/// ```
///
/// 결과는 `build/screenshots/`에 남는다.
const _enabled = bool.fromEnvironment('SCREENSHOT');

/// 갤럭시 S22 정도의 논리 해상도.
const _size = Size(390, 844);

class _StubProfileService implements ProfileService {
  const _StubProfileService(this._profiles);

  final List<ChildProfile> _profiles;

  @override
  Future<List<ChildProfile>> fetchProfiles() async => _profiles;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  if (!_enabled) {
    test('스크린샷은 --dart-define=SCREENSHOT=true 일 때만 찍는다', () {},
        skip: '눈으로 확인하는 용도. 파일 상단 주석 참고.');
    return;
  }

  const user = User(
    userId: 1,
    email: 'parent@example.com',
    role: 'parent',
    status: 'active',
  );

  setUpAll(() async {
    Directory('build/screenshots').createSync(recursive: true);

    // 테스트 환경은 기본 폰트가 비어 있어 한글이 네모로 나온다.
    // 앱이 실제로 쓰는 폰트를 직접 실어 실제 화면과 같게 만든다.
    await _loadFont('CookieRun', [
      'assets/fonts/CookieRun-Regular.ttf',
      'assets/fonts/CookieRun-Bold.ttf',
      'assets/fonts/CookieRun-Black.ttf',
    ]);
    await _loadFont('Quicksand', [
      'assets/fonts/Quicksand-Regular.ttf',
      'assets/fonts/Quicksand-Bold.ttf',
    ]);
    // 아이콘도 폰트라, 안 실으면 전부 네모로 나온다.
    await _loadMaterialIcons();
  });

  /// 화면을 그려서 PNG로 저장한다.
  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget screen, {
    List<Provider<ProfileService>> extraProviders = const [],
    FakeAuthProvider? auth,
    Future<void> Function(WidgetTester tester)? afterPump,
  }) async {
    tester.view
      ..physicalSize = _size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth ?? FakeAuthProvider(),
          ),
          ...extraProviders,
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (afterPump != null) await afterPump(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/screenshots/$name.png'),
    );
  }

  testWidgets('로그인 화면', (tester) async {
    await capture(tester, '01-login', const LoginScreen());
  });

  testWidgets('로그인 화면 - 입력 검증 오류', (tester) async {
    await capture(
      tester,
      '02-login-validation',
      const LoginScreen(),
      afterPump: (tester) async {
        await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('로그인 화면 - 서버 오류', (tester) async {
    await capture(
      tester,
      '03-login-error',
      const LoginScreen(),
      auth: FakeAuthProvider()
        ..errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.',
    );
  });

  testWidgets('회원가입 1단계 - 이메일', (tester) async {
    await capture(tester, '04-signup-step1', const SignupScreen());
  });

  testWidgets('회원가입 2단계 - 인증번호', (tester) async {
    await capture(
      tester,
      '05-signup-step2',
      const SignupScreen(),
      afterPump: (tester) async {
        await tester.enterText(
          find.byType(TextFormField).first,
          'user@example.com',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '인증번호 받기'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('회원가입 3단계 - 비밀번호', (tester) async {
    await capture(
      tester,
      '06-signup-step3',
      const SignupScreen(),
      afterPump: (tester) async {
        await tester.enterText(
          find.byType(TextFormField).first,
          'user@example.com',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '인증번호 받기'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(1), '123456');
        await tester.tap(find.widgetWithText(ElevatedButton, '인증번호 확인'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('비밀번호 재설정 1단계 - 이메일', (tester) async {
    await capture(tester, '07-reset-step1', const PasswordResetScreen());
  });

  testWidgets('비밀번호 재설정 2단계 - 인증번호와 새 비밀번호', (tester) async {
    await capture(
      tester,
      '08-reset-step2',
      const PasswordResetScreen(),
      afterPump: (tester) async {
        await tester.enterText(
          find.byType(TextFormField).first,
          'user@example.com',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '인증번호 받기'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('자녀 프로필 - 비어 있을 때', (tester) async {
    await capture(
      tester,
      '09-profiles-empty',
      const ProfileListScreen(),
      auth: FakeAuthProvider(status: AuthStatus.authenticated, user: user),
      extraProviders: [
        Provider<ProfileService>.value(value: const _StubProfileService([])),
      ],
    );
  });

  testWidgets('자녀 프로필 - 목록', (tester) async {
    await capture(
      tester,
      '10-profiles-list',
      const ProfileListScreen(),
      auth: FakeAuthProvider(status: AuthStatus.authenticated, user: user),
      extraProviders: [
        Provider<ProfileService>.value(
          value: const _StubProfileService([
            ChildProfile(
              childProfileId: 1,
              childName: '민준',
              age: 7,
              learningLevel: LearningLevel.beginner,
              isActive: true,
            ),
            ChildProfile(
              childProfileId: 2,
              childName: '서연',
              age: 10,
              learningLevel: LearningLevel.intermediate,
            ),
          ]),
        ),
      ],
    );
  });

  testWidgets('자녀 프로필 - 추가 시트', (tester) async {
    await capture(
      tester,
      '11-profile-editor',
      const ProfileListScreen(),
      auth: FakeAuthProvider(status: AuthStatus.authenticated, user: user),
      extraProviders: [
        Provider<ProfileService>.value(value: const _StubProfileService([])),
      ],
      afterPump: (tester) async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
      },
    );
  });
}

/// pubspec에 선언된 폰트를 테스트 렌더러에 실어준다.
Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Material 아이콘 폰트는 Flutter SDK 캐시에 있다.
/// 경로가 환경마다 달라서 못 찾으면 조용히 넘어간다(아이콘만 네모로 나온다).
Future<void> _loadMaterialIcons() async {
  final flutterRoot = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.path;
  final candidates = [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '${Platform.environment['FLUTTER_ROOT']}'
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) {
      await _loadFont('MaterialIcons', [path]);
      return;
    }
  }
}
