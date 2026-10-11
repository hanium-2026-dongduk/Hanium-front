import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/usage_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 학습 시간 요약 조회(MP03)가 서버 계약대로 요청하고 응답을 읽는지 본다.
void main() {
  late HttpServer server;
  late UsageService usageService;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api',
    );

    final tokens = {
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    };
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

    usageService = UsageService(
      ApiClient(tokenStorage: TokenStorage(storage: storage)),
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

  test('자녀 id로 사용 시간 요약 경로를 부르고 기간 합계와 일별 기록을 읽는다', () async {
    Uri? uri;
    handler = (request) async {
      uri = request.uri;
      await respond(request, 200, {
        'success': true,
        'message': '기간별 사용 시간을 조회했습니다.',
        'data': {
          'from': '2026-09-28',
          'to': '2026-10-04',
          'totalAccumulatedSeconds': 5400,
          'days': [
            {'date': '2026-09-30', 'accumulatedSeconds': 1800},
            {'date': '2026-10-04', 'accumulatedSeconds': '3600'},
          ],
        },
      });
    };

    final summary = await usageService.fetchSummary(7);

    expect(uri!.path, '/api/usage/7/summary');
    // 기간을 안 주면 서버 기본값(최근 7일)을 쓰도록 쿼리를 붙이지 않는다.
    expect(uri!.queryParameters, isEmpty);
    expect(summary.from, '2026-09-28');
    expect(summary.to, '2026-10-04');
    expect(summary.totalAccumulatedSeconds, 5400);
    expect(summary.days, hasLength(2));
    expect(summary.days.last.accumulatedSeconds, 3600);
  });

  test('기간을 주면 from·to 쿼리로 보낸다', () async {
    Uri? uri;
    handler = (request) async {
      uri = request.uri;
      await respond(request, 200, {
        'success': true,
        'message': 'ok',
        'data': {
          'from': '2026-09-01',
          'to': '2026-09-30',
          'totalAccumulatedSeconds': 0,
          'days': [],
        },
      });
    };

    final summary = await usageService.fetchSummary(
      7,
      from: '2026-09-01',
      to: '2026-09-30',
    );

    expect(uri!.queryParameters, {'from': '2026-09-01', 'to': '2026-09-30'});
    expect(summary.totalAccumulatedSeconds, 0);
    expect(summary.days, isEmpty);
  });

  test('heartbeat는 자녀 id만 담아 POST로 보낸다', () async {
    String? method;
    Uri? uri;
    Object? body;
    handler = (request) async {
      method = request.method;
      uri = request.uri;
      body = jsonDecode(await utf8.decodeStream(request));
      await respond(request, 200, {
        'success': true,
        'message': '사용 시간이 기록되었습니다.',
        'data': {
          'accumulatedSeconds': 30,
          'limitSeconds': null,
          'remainingSeconds': null,
        },
      });
    };

    await usageService.sendHeartbeat(7);

    expect(method, 'POST');
    expect(uri!.path, '/api/usage/heartbeat');
    expect(body, {'child_profile_id': 7});
  });

  test('heartbeat 한도 초과(403)는 ApiException으로 던진다', () async {
    handler = (request) async {
      await respond(request, 403, {
        'success': false,
        'message': '오늘의 사용 시간이 초과되었습니다.',
      });
    };

    expect(
      () => usageService.sendHeartbeat(7),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('서버 오류면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 404, {
        'success': false,
        'message': '자녀 프로필을 찾을 수 없습니다.',
      });
    };

    expect(
      () => usageService.fetchSummary(7),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', '자녀 프로필을 찾을 수 없습니다.'),
      ),
    );
  });
}
