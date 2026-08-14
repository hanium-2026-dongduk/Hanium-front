import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late HttpServer server;
  late Map<String, String> tokens;
  late _MockSecureStorage secureStorage;
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );

    tokens = {
      'access_token': 'old-access-token',
      'refresh_token': 'old-refresh-token',
    };
    secureStorage = _MockSecureStorage();
    when(
      () => secureStorage.read(key: any(named: 'key')),
    ).thenAnswer((invocation) async => tokens[invocation.namedArguments[#key]]);
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      tokens[invocation.namedArguments[#key] as String] =
          invocation.namedArguments[#value] as String;
    });
    when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      tokens.remove(invocation.namedArguments[#key]);
    });

    tokenStorage = TokenStorage(storage: secureStorage);
    apiClient = ApiClient(tokenStorage: tokenStorage);
    server.listen((request) async => handler(request));
  });

  tearDown(() async {
    await server.close(force: true);
    dotenv.clean();
  });

  Future<void> respond(
    HttpRequest request,
    int statusCode, [
    Map<String, dynamic>? body,
  ]) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body ?? <String, dynamic>{}));
    await request.response.close();
  }

  test('저장된 액세스 토큰을 Bearer 헤더로 자동 첨부한다', () async {
    String? authorization;
    handler = (request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      await respond(request, 200, {'ok': true});
    };

    await apiClient.dio.get<Map<String, dynamic>>('/protected');

    expect(authorization, 'Bearer old-access-token');
  });

  test('401이면 토큰을 갱신하고 새 토큰으로 원래 요청을 한 번 재시도한다', () async {
    var protectedCalls = 0;
    var refreshCalls = 0;
    final authorizations = <String?>[];
    handler = (request) async {
      if (request.uri.path == '/api/auth/refresh') {
        refreshCalls++;
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'refreshToken': 'old-refresh-token',
        });
        await respond(request, 200, {
          'accessToken': 'new-access-token',
          'refreshToken': 'rotated-refresh-token',
        });
        return;
      }
      protectedCalls++;
      authorizations.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      await respond(
        request,
        protectedCalls == 1 ? 401 : 200,
        protectedCalls == 1 ? {'message': '만료'} : {'ok': true},
      );
    };

    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/protected',
    );

    expect(response.data, {'ok': true});
    expect(protectedCalls, 2);
    expect(refreshCalls, 1);
    expect(authorizations, [
      'Bearer old-access-token',
      'Bearer new-access-token',
    ]);
    expect(tokens['access_token'], 'new-access-token');
    expect(tokens['refresh_token'], 'rotated-refresh-token');
  });

  test('리프레시 토큰이 회전되지 않으면 기존 리프레시 토큰을 보존한다', () async {
    var protectedCalls = 0;
    handler = (request) async {
      if (request.uri.path == '/api/auth/refresh') {
        await respond(request, 200, {'accessToken': 'new-access-token'});
        return;
      }
      protectedCalls++;
      await respond(request, protectedCalls == 1 ? 401 : 200);
    };

    await apiClient.dio.get<void>('/protected');

    expect(tokens['access_token'], 'new-access-token');
    expect(tokens['refresh_token'], 'old-refresh-token');
  });

  test('리프레시 실패 시 토큰을 삭제하고 만료 콜백 뒤 원래 401을 전파한다', () async {
    var expiredCalls = 0;
    apiClient.onSessionExpired = () async => expiredCalls++;
    handler = (request) async {
      if (request.uri.path == '/api/auth/refresh') {
        await respond(request, 401, {'message': '리프레시 실패'});
        return;
      }
      await respond(request, 401, {'message': '원래 요청 실패'});
    };

    await expectLater(
      apiClient.dio.get<void>('/protected'),
      throwsA(
        isA<DioException>()
            .having((error) => error.response?.statusCode, '상태 코드', 401)
            .having((error) => error.response?.data, '원래 응답', {
              'message': '원래 요청 실패',
            }),
      ),
    );
    expect(tokens, isEmpty);
    expect(expiredCalls, 1);
  });

  test('재시도한 요청도 401이면 다시 리프레시하지 않아 무한루프를 막는다', () async {
    var refreshCalls = 0;
    var protectedCalls = 0;
    handler = (request) async {
      if (request.uri.path == '/api/auth/refresh') {
        refreshCalls++;
        await respond(request, 200, {'accessToken': 'new-token'});
        return;
      }
      protectedCalls++;
      await respond(request, 401, {'message': '계속 실패'});
    };

    await expectLater(
      apiClient.dio.get<void>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(protectedCalls, 2);
    expect(refreshCalls, 1);
  });

  test('인증 엔드포인트의 401은 리프레시하지 않고 바로 전파한다', () async {
    final calls = <String, int>{};
    handler = (request) async {
      calls[request.uri.path] = (calls[request.uri.path] ?? 0) + 1;
      await respond(request, 401, {'message': '인증 실패'});
    };

    for (final path in ['/auth/login', '/auth/signup', '/auth/refresh']) {
      await expectLater(
        apiClient.dio.post<void>(path),
        throwsA(isA<DioException>()),
      );
    }

    expect(calls, {
      '/api/auth/login': 1,
      '/api/auth/signup': 1,
      '/api/auth/refresh': 1,
    });
  });

  test('동시에 여러 요청이 401이어도 리프레시는 한 번만 공유한다', () async {
    var refreshCalls = 0;
    final attempts = <String, int>{};
    final bothInitialRequestsArrived = Completer<void>();
    var initialRequests = 0;
    handler = (request) async {
      if (request.uri.path == '/api/auth/refresh') {
        refreshCalls++;
        await bothInitialRequestsArrived.future;
        await respond(request, 200, {'accessToken': 'shared-new-token'});
        return;
      }

      final path = request.uri.path;
      attempts[path] = (attempts[path] ?? 0) + 1;
      if (attempts[path] == 1) {
        initialRequests++;
        if (initialRequests == 2) bothInitialRequestsArrived.complete();
        await respond(request, 401);
        return;
      }
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer shared-new-token',
      );
      await respond(request, 200, {'path': path});
    };

    final responses = await Future.wait([
      apiClient.dio.get<Map<String, dynamic>>('/first'),
      apiClient.dio.get<Map<String, dynamic>>('/second'),
    ]);

    expect(refreshCalls, 1);
    expect(attempts, {'/api/first': 2, '/api/second': 2});
    expect(responses.map((response) => response.statusCode), everyElement(200));
  });
}
