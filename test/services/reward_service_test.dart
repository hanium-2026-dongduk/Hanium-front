import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 보상 포인트 조회(MN02)가 서버 계약대로 요청하고 응답을 읽는지 본다.
/// 실제 Dio 인터셉터를 타도록 로컬 서버를 띄운다.
void main() {
  late HttpServer server;
  late ApiClient apiClient;
  late RewardService rewardService;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );

    // 401을 받으면 ApiClient가 리프레시를 시도하고 실패 시 토큰을 지우므로,
    // 읽기뿐 아니라 쓰기·삭제까지 동작하는 가짜 저장소가 필요하다.
    final tokens = {
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    };
    final storage = _MockSecureStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => tokens[call.namedArguments[#key]]);
    when(
      () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((call) async {
      tokens[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((call) async => tokens.remove(call.namedArguments[#key]));

    apiClient = ApiClient(tokenStorage: TokenStorage(storage: storage));
    rewardService = RewardService(apiClient);
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

  test('자녀 id로 요약 경로를 부르고 data.points를 읽는다', () async {
    String? path;
    handler = (request) async {
      path = request.uri.path;
      await respond(request, 200, {
        'success': true,
        'message': '보유 포인트를 조회했습니다.',
        'data': {'points': 340},
      });
    };

    expect(await rewardService.fetchPointBalance(7), 340);
    expect(path, '/api/rewards/7/summary');
  });

  test('포인트가 0이어도 그대로 읽는다', () async {
    // 지갑이 없던 자녀는 서버가 만들어 주므로 0으로 시작한다.
    handler = (request) async {
      await respond(request, 200, {
        'success': true,
        'data': {'points': 0},
      });
    };

    expect(await rewardService.fetchPointBalance(1), 0);
  });

  test('BIGINT가 문자열로 와도 정수로 읽는다', () async {
    handler = (request) async {
      await respond(request, 200, {
        'success': true,
        'data': {'points': '1250'},
      });
    };

    expect(await rewardService.fetchPointBalance(1), 1250);
  });

  test('내 자녀가 아니면 404를 ApiException으로 전한다', () async {
    handler = (request) async {
      await respond(request, 404, {
        'success': false,
        'message': '자녀 프로필을 찾을 수 없습니다.',
      });
    };

    await expectLater(
      rewardService.fetchPointBalance(999),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, '상태 코드', 404)
            .having((e) => e.message, '메시지', '자녀 프로필을 찾을 수 없습니다.'),
      ),
    );
  });

  test('토큰이 만료돼 갱신까지 실패하면 401을 그대로 전한다', () async {
    // 보상 API는 인증이 필요하므로 401이면 ApiClient가 리프레시를 한 번 시도한다.
    // 그것까지 실패하면 원래 401이 올라와야 한다.
    var refreshCalls = 0;
    handler = (request) async {
      if (request.uri.path == '/api/auth/refresh') refreshCalls++;
      await respond(request, 401, {
        'success': false,
        'message': '인증이 필요합니다.',
      });
    };

    await expectLater(
      rewardService.fetchPointBalance(1),
      throwsA(
        isA<ApiException>().having((e) => e.isUnauthorized, '401 여부', isTrue),
      ),
    );
    expect(refreshCalls, 1);
  });

  test('Bearer 헤더가 자동으로 붙는다', () async {
    String? authorization;
    handler = (request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      await respond(request, 200, {
        'success': true,
        'data': {'points': 10},
      });
    };

    await rewardService.fetchPointBalance(1);

    expect(authorization, 'Bearer access-token');
  });
}
