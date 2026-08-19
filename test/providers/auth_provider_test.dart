import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/services/auth_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileService extends Mock implements ProfileService {}

class _MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  const user = User(
    userId: 1,
    email: 'user@example.com',
    role: 'parent',
    status: 'active',
  );
  const authResult = AuthResult(
    user: user,
    accessToken: '액세스-토큰',
    refreshToken: '리프레시-토큰',
  );

  late _MockAuthService authService;
  late _MockProfileService profileService;
  late _MockTokenStorage tokenStorage;
  late AuthProvider provider;
  late int notifications;

  setUpAll(() {
    registerFallbackValue(user);
  });

  setUp(() {
    authService = _MockAuthService();
    profileService = _MockProfileService();
    tokenStorage = _MockTokenStorage();
    provider = AuthProvider(
      authService: authService,
      profileService: profileService,
      tokenStorage: tokenStorage,
    );
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  /// 로그인 성공 경로가 공통으로 필요한 스텁.
  void stubSuccessfulLogin() {
    when(
      () => authService.login(email: 'user@example.com', password: 'password'),
    ).thenAnswer((_) async => authResult);
    when(
      () => tokenStorage.saveTokens(
        accessToken: '액세스-토큰',
        refreshToken: '리프레시-토큰',
      ),
    ).thenAnswer((_) async {});
    when(() => tokenStorage.saveUser(any())).thenAnswer((_) async {});
  }

  group('bootstrap은', () {
    test('저장된 액세스 토큰이 없으면 비로그인 상태를 알린다', () async {
      when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
      when(() => tokenStorage.readUser()).thenAnswer((_) async => null);

      await provider.bootstrap();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.user, isNull);
      expect(notifications, 1);
      verifyNever(() => profileService.fetchProfiles());
    });

    test('토큰은 있어도 저장된 사용자가 없으면 비로그인 상태로 둔다', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => '저장된-토큰');
      when(() => tokenStorage.readUser()).thenAnswer((_) async => null);

      await provider.bootstrap();

      expect(provider.status, AuthStatus.unauthenticated);
      verifyNever(() => profileService.fetchProfiles());
    });

    test('저장된 토큰으로 인증 API가 통하면 저장된 사용자를 복원한다', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => '저장된-토큰');
      when(() => tokenStorage.readUser()).thenAnswer((_) async => user);
      when(
        () => profileService.fetchProfiles(),
      ).thenAnswer((_) async => <ChildProfile>[]);

      await provider.bootstrap();

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user, same(user));
      expect(notifications, 1);
      verifyNever(() => tokenStorage.clear());
    });

    test('토큰이 만료돼 401이면 저장된 값을 지우고 비로그인 상태를 알린다', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => '만료된-토큰');
      when(() => tokenStorage.readUser()).thenAnswer((_) async => user);
      when(
        () => profileService.fetchProfiles(),
      ).thenThrow(const ApiException(message: '인증 실패', statusCode: 401));
      when(() => tokenStorage.clear()).thenAnswer((_) async {});

      await provider.bootstrap();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.user, isNull);
      verify(() => tokenStorage.clear()).called(1);
    });

    test('401이 아닌 네트워크 오류면 세션을 버리지 않고 로그인 상태를 유지한다', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => '저장된-토큰');
      when(() => tokenStorage.readUser()).thenAnswer((_) async => user);
      when(
        () => profileService.fetchProfiles(),
      ).thenThrow(const ApiException(message: '서버에 연결할 수 없어요.'));

      await provider.bootstrap();

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user, same(user));
      verifyNever(() => tokenStorage.clear());
    });
  });

  test('로그인은 제출 시작과 성공 완료를 알리고 토큰과 사용자를 저장한다', () async {
    final pendingLogin = Completer<AuthResult>();
    when(
      () => authService.login(email: 'user@example.com', password: 'password'),
    ).thenAnswer((_) => pendingLogin.future);
    when(
      () => tokenStorage.saveTokens(
        accessToken: '액세스-토큰',
        refreshToken: '리프레시-토큰',
      ),
    ).thenAnswer((_) async {});
    when(() => tokenStorage.saveUser(any())).thenAnswer((_) async {});

    final resultFuture = provider.login(
      email: 'user@example.com',
      password: 'password',
    );
    expect(provider.isSubmitting, isTrue);
    expect(provider.errorMessage, isNull);
    expect(notifications, 1);

    pendingLogin.complete(authResult);
    expect(await resultFuture, isTrue);
    expect(provider.isSubmitting, isFalse);
    expect(provider.status, AuthStatus.authenticated);
    expect(provider.user, same(user));
    expect(notifications, 2);
    verify(
      () => tokenStorage.saveTokens(
        accessToken: '액세스-토큰',
        refreshToken: '리프레시-토큰',
      ),
    ).called(1);
    // /users/me가 없어서 다음 실행 때 복원하려면 사용자도 같이 저장해야 한다.
    verify(() => tokenStorage.saveUser(user)).called(1);
  });

  test('로그인 실패도 제출 상태를 finally에서 해제하고 오류를 알린다', () async {
    when(
      () => authService.login(email: 'user@example.com', password: 'wrong'),
    ).thenThrow(const ApiException(message: '이메일 또는 비밀번호가 올바르지 않습니다.'));

    final result = await provider.login(
      email: 'user@example.com',
      password: 'wrong',
    );

    expect(result, isFalse);
    expect(provider.isSubmitting, isFalse);
    expect(provider.errorMessage, '이메일 또는 비밀번호가 올바르지 않습니다.');
    expect(notifications, 2);
    verifyNever(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );
  });

  group('회원가입 3단계는', () {
    test('1단계에서 인증번호 발송을 요청한다', () async {
      when(
        () => authService.sendSignupCode('new@example.com'),
      ).thenAnswer((_) async {});

      expect(await provider.sendSignupCode('new@example.com'), isTrue);
      expect(provider.isSubmitting, isFalse);
      // 발송만으로 로그인 상태가 되면 안 된다.
      expect(provider.status, AuthStatus.unknown);
      verify(() => authService.sendSignupCode('new@example.com')).called(1);
    });

    test('1단계 실패(이미 가입된 이메일 등)는 오류 메시지를 남긴다', () async {
      when(
        () => authService.sendSignupCode('used@example.com'),
      ).thenThrow(const ApiException(message: '이미 가입된 이메일입니다.', statusCode: 409));

      expect(await provider.sendSignupCode('used@example.com'), isFalse);
      expect(provider.errorMessage, '이미 가입된 이메일입니다.');
      expect(provider.isSubmitting, isFalse);
    });

    test('2단계에서 인증번호를 검증한다', () async {
      when(
        () => authService.verifySignupCode(
          email: 'new@example.com',
          code: '123456',
        ),
      ).thenAnswer((_) async {});

      expect(
        await provider.verifySignupCode(
          email: 'new@example.com',
          code: '123456',
        ),
        isTrue,
      );
      verify(
        () => authService.verifySignupCode(
          email: 'new@example.com',
          code: '123456',
        ),
      ).called(1);
    });

    test('3단계는 가입 뒤 곧바로 로그인까지 이어서 로그인 상태로 만든다', () async {
      when(
        () => authService.signup(
          email: 'user@example.com',
          password: 'password',
        ),
      ).thenAnswer((_) async => user);
      stubSuccessfulLogin();

      final result = await provider.signup(
        email: 'user@example.com',
        password: 'password',
      );

      expect(result, isTrue);
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user, same(user));
      // 서버가 가입 응답으로 토큰을 주지 않으므로 로그인 호출이 반드시 뒤따라야 한다.
      verifyInOrder([
        () => authService.signup(
          email: 'user@example.com',
          password: 'password',
        ),
        () => authService.login(
          email: 'user@example.com',
          password: 'password',
        ),
      ]);
    });

    test('가입이 실패하면 로그인을 시도하지 않는다', () async {
      when(
        () => authService.signup(
          email: 'user@example.com',
          password: 'password',
        ),
      ).thenThrow(
        const ApiException(message: '이메일 인증이 완료되지 않았습니다.', statusCode: 403),
      );

      final result = await provider.signup(
        email: 'user@example.com',
        password: 'password',
      );

      expect(result, isFalse);
      expect(provider.errorMessage, '이메일 인증이 완료되지 않았습니다.');
      expect(provider.status, AuthStatus.unknown);
      verifyNever(
        () => authService.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });

  test('logout은 저장된 리프레시 토큰을 서버에 넘겨 폐기시킨다', () async {
    stubSuccessfulLogin();
    when(
      () => tokenStorage.readRefreshToken(),
    ).thenAnswer((_) async => '리프레시-토큰');
    when(() => authService.logout(any())).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
    await provider.login(email: 'user@example.com', password: 'password');
    notifications = 0;

    await provider.logout();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.user, isNull);
    expect(notifications, 1);
    // 서버가 폐기할 토큰을 알아야 하므로 지우기 전에 읽어서 넘겨야 한다.
    verifyInOrder([
      () => tokenStorage.readRefreshToken(),
      () => authService.logout('리프레시-토큰'),
      () => tokenStorage.clear(),
    ]);
  });

  test('세션 만료는 로그인 상태를 초기화하고 만료 메시지를 알린다', () async {
    stubSuccessfulLogin();
    await provider.login(email: 'user@example.com', password: 'password');
    notifications = 0;

    await provider.handleSessionExpired();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.user, isNull);
    expect(provider.errorMessage, '로그인이 만료되었어요. 다시 로그인해 주세요.');
    expect(notifications, 1);
  });

  test('이미 비로그인 상태면 세션 만료 처리를 조기 종료해 다시 알리지 않는다', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
    when(() => tokenStorage.readUser()).thenAnswer((_) async => null);
    await provider.bootstrap();
    notifications = 0;

    await provider.handleSessionExpired();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.errorMessage, isNull);
    expect(notifications, 0);
  });
}
