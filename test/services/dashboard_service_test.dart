import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/dashboard_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 학습 대시보드 요약 조회(MP03)가 서버 계약대로 요청하고 응답을 읽는지 본다.
void main() {
  late HttpServer server;
  late DashboardService dashboardService;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api');

    final tokens = {'access_token': 'access-token', 'refresh_token': 'refresh-token'};
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
      tokens[call.namedArguments[#key] as String] = call.namedArguments[#value] as String;
    });
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((call) async => tokens.remove(call.namedArguments[#key]));

    dashboardService = DashboardService(ApiClient(tokenStorage: TokenStorage(storage: storage)));
    server.listen((request) async => handler(request));
  });

  tearDown(() async {
    await server.close(force: true);
    dotenv.clean();
  });

  Future<void> respond(HttpRequest request, int statusCode, Map<String, dynamic> body) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  test('자녀 id로 대시보드 경로를 부르고 집계를 읽는다', () async {
    String? path;
    String? auth;
    handler = (request) async {
      path = request.uri.path;
      auth = request.headers.value('authorization');
      await respond(request, 200, {
        'success': true,
        'message': '대시보드를 조회했습니다.',
        'data': {
          'storyCount': 12,
          'favoriteStoryCount': 3,
          'vocabularyCount': 40,
          'quizStats': {
            'totalAttempts': 5,
            'averageScore': 82.5,
            'lastAttemptAt': '2026-09-20T05:00:00.000Z',
          },
        },
      });
    };

    final summary = await dashboardService.fetchSummary(7);

    expect(path, '/api/dashboard/7');
    expect(auth, 'Bearer access-token');
    expect(summary.storyCount, 12);
    expect(summary.favoriteStoryCount, 3);
    expect(summary.vocabularyCount, 40);
    expect(summary.quizStats.totalAttempts, 5);
    expect(summary.quizStats.averageScore, 82.5);
    expect(summary.quizStats.lastAttemptAt, isNotNull);
  });

  test('퀴즈 기록이 없으면 평균 점수는 null이다', () async {
    handler = (request) async {
      await respond(request, 200, {
        'success': true,
        'message': 'ok',
        'data': {
          'storyCount': 0,
          'favoriteStoryCount': 0,
          'vocabularyCount': 0,
          'quizStats': {'totalAttempts': 0, 'averageScore': null, 'lastAttemptAt': null},
        },
      });
    };

    final summary = await dashboardService.fetchSummary(7);

    expect(summary.quizStats.totalAttempts, 0);
    expect(summary.quizStats.averageScore, isNull);
    expect(summary.quizStats.lastAttemptAt, isNull);
  });

  test('서버 오류면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 500, {'success': false, 'message': '잠시 후 다시 시도해 주세요.'});
    };

    expect(
      () => dashboardService.fetchSummary(7),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', '잠시 후 다시 시도해 주세요.'),
      ),
    );
  });
}
