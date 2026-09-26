import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/models/badge_status.dart';
import 'package:hanium_front/services/badge_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 배지 조회(RW04·MP02)가 서버 계약(snake_case)대로 요청하고 응답을 읽는지 본다.
void main() {
  late HttpServer server;
  late BadgeService badgeService;
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

    badgeService = BadgeService(ApiClient(tokenStorage: TokenStorage(storage: storage)));
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

  test('자녀 id로 배지 경로를 부르고 snake_case 응답을 읽는다', () async {
    String? path;
    String? auth;
    handler = (request) async {
      path = request.uri.path;
      auth = request.headers.value('authorization');
      await respond(request, 200, {
        'success': true,
        'message': '배지 목록을 조회했습니다.',
        'data': {
          'badges': [
            {
              'badge_code': 'streak_10',
              'name': '불꽃 출석왕',
              'description': '10일 연속 출석',
              'icon_key': 'fire',
              'condition': {'type': 'streak_days', 'value': 10},
              'status': 'earned',
              'awarded_at': '2026-09-01T00:00:00.000Z',
            },
            {
              'badge_code': 'story_10',
              'name': '동화 박사',
              'description': '동화 10편 읽기',
              'icon_key': 'book',
              'condition': {'type': 'story_read_total', 'value': 10},
              'status': 'locked',
              'awarded_at': null,
            },
          ],
          'earned_count': 1,
          'total_count': 2,
        },
      });
    };

    final summary = await badgeService.fetchChildBadges(7);

    expect(path, '/api/badges/7');
    expect(auth, 'Bearer access-token');
    expect(summary.earnedCount, 1);
    expect(summary.totalCount, 2);
    expect(summary.badges.first.state, BadgeState.earned);
    expect(summary.badges.first.awardedAt, isNotNull);
    expect(summary.badges.last.isEarned, isFalse);
    expect(summary.badges.last.condition.hint, contains('10편'));
  });

  test('알 수 없는 status는 잠김으로, coming_soon은 그대로 읽는다', () {
    expect(BadgeState.fromServer('nope'), BadgeState.locked);
    expect(BadgeState.fromServer(null), BadgeState.locked);
    expect(BadgeState.fromServer('coming_soon'), BadgeState.comingSoon);
  });

  test('자기 자녀가 아니면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 404, {'success': false, 'message': '자녀 프로필을 찾을 수 없습니다.'});
    };

    expect(
      () => badgeService.fetchChildBadges(99),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', '자녀 프로필을 찾을 수 없습니다.'),
      ),
    );
  });
}
