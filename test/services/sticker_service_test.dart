import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/sticker_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 받은 칭찬 스티커 조회(MP05)가 서버 계약(snake_case + 페이지네이션)대로 동작하는지 본다.
void main() {
  late HttpServer server;
  late StickerService stickerService;
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

    stickerService = StickerService(ApiClient(tokenStorage: TokenStorage(storage: storage)));
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

  test('자녀 id와 페이지 쿼리로 요청하고 snake_case 응답을 읽는다', () async {
    String? path;
    Map<String, String>? query;
    String? auth;
    handler = (request) async {
      path = request.uri.path;
      query = request.uri.queryParameters;
      auth = request.headers.value('authorization');
      await respond(request, 200, {
        'success': true,
        'message': '받은 스티커를 조회했습니다.',
        'data': {
          'items': [
            {
              'sticker_send_id': 11,
              'sticker_code': 'star',
              'name': '별 스티커',
              'icon_key': 'star',
              'message': '오늘도 잘했어!',
              'sent_at': '2026-09-01T03:00:00.000Z',
            },
            {
              'sticker_send_id': 10,
              'sticker_code': 'heart',
              'name': '하트 스티커',
              'icon_key': null,
              'message': null,
              'sent_at': '2026-08-31T03:00:00.000Z',
            },
          ],
          'pagination': {'page': 2, 'limit': 2, 'totalCount': 5, 'totalPages': 3},
        },
      });
    };

    final result = await stickerService.fetchReceived(7, page: 2, limit: 2);

    expect(path, '/api/stickers/received/7');
    expect(query, {'page': '2', 'limit': '2'});
    expect(auth, 'Bearer access-token');
    expect(result.items, hasLength(2));
    expect(result.items.first.stickerSendId, 11);
    expect(result.items.first.name, '별 스티커');
    expect(result.items.first.message, '오늘도 잘했어!');
    expect(result.items.first.sentAt, isNotNull);
    expect(result.items.last.iconKey, isNull);
    expect(result.items.last.message, isNull);
    expect(result.page, 2);
    expect(result.hasMore, isTrue);
  });

  test('자기 자녀가 아니면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 404, {'success': false, 'message': '자녀 프로필을 찾을 수 없습니다.'});
    };

    expect(
      () => stickerService.fetchReceived(99),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', '자녀 프로필을 찾을 수 없습니다.'),
      ),
    );
  });
}
