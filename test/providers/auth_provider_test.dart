import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  const user = User(id: 1, email: 'user@example.com', name: '보호자');
  const authResult = AuthResult(
    user: user,
    accessToken: '액세스-토큰',
    refreshToken: '리프레시-토큰',
  );

  late _MockAuthService authService;
  late _MockTokenStorage tokenStorage;
  late AuthProvider provider;
  late int notifications;

  setUp(() {
    authService = _MockAuthService();
    tokenStorage = _MockTokenStorage();
    provider = AuthProvider(
      authService: authService,
      tokenStorage: tokenStorage,
    );
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  group('bootstrap은', () {
    test('저장된 액세스 토큰이 없으면 비로그인 상태를 알린다', () async {
      when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);

      await provider.bootstrap();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.user, isNull);
      expect(notifications, 1);
      verifyNever(() => authService.fetchMe());
    });

    test('저장된 토큰으로 사용자 조회에 성공하면 로그인 상태를 알린다', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => '저장된-토큰');
      when(() => authService.fetchMe()).thenAnswer((_) async => user);

      await provider.bootstrap();

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user, same(user));
      expect(notifications, 1);
      verifyNever(() => tokenStorage.clear());
    });

    test('사용자 조회가 ApiException으로 실패하면 토큰을 지우고 비로그인 상태를 알린다', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => '만료된-토큰');
      when(
        () => authService.fetchMe(),
      ).thenThrow(const ApiException(message: '인증 실패', statusCode: 401));
      when(() => tokenStorage.clear()).thenAnswer((_) async {});

      await provider.bootstrap();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.user, isNull);
      expect(notifications, 1);
      verify(() => tokenStorage.clear()).called(1);
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
  });

  test('로그인 실패도 제출 상태를 finally에서 해제하고 오류를 알린다', () async {
    when(
      () => authService.login(email: 'user@example.com', password: 'wrong'),
    ).thenThrow(const ApiException(message: '비밀번호가 달라요.'));

    final result = await provider.login(
      email: 'user@example.com',
      password: 'wrong',
    );

    expect(result, isFalse);
    expect(provider.isSubmitting, isFalse);
    expect(provider.status, AuthStatus.unknown);
    expect(provider.errorMessage, '비밀번호가 달라요.');
    expect(notifications, 2);
    verifyNever(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );
  });

  test('회원가입 성공은 모든 입력을 전달하고 토큰 저장 뒤 제출 상태를 해제한다', () async {
    when(
      () => authService.signup(
        email: 'new@example.com',
        password: 'password',
        name: '새 보호자',
      ),
    ).thenAnswer((_) async => authResult);
    when(
      () => tokenStorage.saveTokens(
        accessToken: '액세스-토큰',
        refreshToken: '리프레시-토큰',
      ),
    ).thenAnswer((_) async {});

    final result = await provider.signup(
      email: 'new@example.com',
      password: 'password',
      name: '새 보호자',
    );

    expect(result, isTrue);
    expect(provider.isSubmitting, isFalse);
    expect(provider.status, AuthStatus.authenticated);
    expect(notifications, 2);
    verify(
      () => authService.signup(
        email: 'new@example.com',
        password: 'password',
        name: '새 보호자',
      ),
    ).called(1);
  });

  test('회원가입 실패도 제출 상태를 finally에서 해제하고 오류를 알린다', () async {
    when(
      () => authService.signup(
        email: 'used@example.com',
        password: 'password',
        name: '보호자',
      ),
    ).thenThrow(const ApiException(message: '이미 가입된 이메일이에요.'));

    final result = await provider.signup(
      email: 'used@example.com',
      password: 'password',
      name: '보호자',
    );

    expect(result, isFalse);
    expect(provider.isSubmitting, isFalse);
    expect(provider.errorMessage, '이미 가입된 이메일이에요.');
    expect(notifications, 2);
  });

  test('logout은 서버 로그아웃과 토큰 삭제 후 사용자와 상태를 초기화한다', () async {
    when(
      () => authService.login(email: 'user@example.com', password: 'password'),
    ).thenAnswer((_) async => authResult);
    when(
      () => tokenStorage.saveTokens(
        accessToken: '액세스-토큰',
        refreshToken: '리프레시-토큰',
      ),
    ).thenAnswer((_) async {});
    when(() => authService.logout()).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
    await provider.login(email: 'user@example.com', password: 'password');
    notifications = 0;

    await provider.logout();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.user, isNull);
    expect(notifications, 1);
    verifyInOrder([() => authService.logout(), () => tokenStorage.clear()]);
  });

  test('세션 만료는 로그인 상태를 초기화하고 만료 메시지를 알린다', () async {
    when(
      () => authService.login(email: 'user@example.com', password: 'password'),
    ).thenAnswer((_) async => authResult);
    when(
      () => tokenStorage.saveTokens(
        accessToken: '액세스-토큰',
        refreshToken: '리프레시-토큰',
      ),
    ).thenAnswer((_) async {});
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
    await provider.bootstrap();
    notifications = 0;

    await provider.handleSessionExpired();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.errorMessage, isNull);
    expect(notifications, 0);
  });
}
