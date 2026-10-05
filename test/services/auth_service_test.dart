import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 비밀번호 변경(ST06)이 서버 계약대로 요청하고, 현재 비밀번호 불일치(401)가
/// 세션 만료로 오인되지 않는지 본다.
void main() {
  late HttpServer server;
  late AuthService authService;
  late Map<String, String> tokens;
  late int sessionExpiredCalls;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );

    tokens = {'access_token': 'access-token', 'refresh_token': 'refresh-token'};
    final storage = _MockSecureStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => tokens[call.namedArguments[#key]]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      tokens[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((call) async => tokens.remove(call.namedArguments[#key]));

    sessionExpiredCalls = 0;
    authService = AuthService(
      ApiClient(
        tokenStorage: TokenStorage(storage: storage),
        onSessionExpired: () async => sessionExpiredCalls++,
      ),
    );
    server.listen((request) async => handler(request));
  });

  tearDown(() async {
    await server.close(force: true);
    dotenv.clean();
  });

  Future<void> respond(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  test('현재·새 비밀번호를 담아 토큰과 함께 PUT /auth/password/change를 부른다', () async {
    String? method;
    String? path;
    String? auth;
    Map<String, dynamic>? body;
    handler = (request) async {
      method = request.method;
      path = request.uri.path;
      auth = request.headers.value(HttpHeaders.authorizationHeader);
      body =
          jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;
      await respond(request, 200, {
        'success': true,
        'message': '비밀번호가 변경되었습니다. 다시 로그인해주세요.',
      });
    };

    await authService.changePassword(
      currentPassword: 'Current1!',
      newPassword: 'Password1!',
    );

    expect(method, 'PUT');
    expect(path, '/api/auth/password/change');
    expect(auth, 'Bearer access-token');
    expect(body, {'currentPassword': 'Current1!', 'newPassword': 'Password1!'});
  });

  test('현재 비밀번호가 틀리면(401) 서버 메시지로 실패하고 세션은 유지한다', () async {
    final paths = <String>[];
    handler = (request) async {
      paths.add(request.uri.path);
      if (request.uri.path == '/api/auth/refresh') {
        await respond(request, 200, {
          'success': true,
          'data': {
            'accessToken': 'new-access-token',
            'refreshToken': 'new-refresh-token',
          },
        });
        return;
      }
      await respond(request, 401, {
        'success': false,
        'message': '현재 비밀번호가 일치하지 않습니다.',
      });
    };

    await expectLater(
      authService.changePassword(
        currentPassword: 'wrong',
        newPassword: 'Password1!',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', '현재 비밀번호가 일치하지 않습니다.'),
      ),
    );

    // 인증 엔드포인트라 갱신 후 한 번 재시도하지만, 그 이상 반복하지 않는다.
    expect(paths, [
      '/api/auth/password/change',
      '/api/auth/refresh',
      '/api/auth/password/change',
    ]);
    expect(sessionExpiredCalls, 0);
    expect(tokens['refresh_token'], 'new-refresh-token');
  });

  test('새 비밀번호가 정책에 맞지 않으면(400) 서버 메시지로 실패한다', () async {
    handler = (request) async {
      await respond(request, 400, {
        'success': false,
        'message': '입력값을 확인해주세요.',
      });
    };

    await expectLater(
      authService.changePassword(
        currentPassword: 'Current1!',
        newPassword: 'short',
      ),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });
}
