import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/vocabulary_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 단어장 서비스(VB01/VB03)가 서버 계약대로 요청하고 응답을 읽는지 본다.
/// 실제 Dio 인터셉터를 타도록 로컬 서버를 띄운다.
void main() {
  late HttpServer server;
  late ApiClient apiClient;
  late VocabularyService vocabularyService;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:${server.port}/api');

    final tokens = {'access_token': 'access-token', 'refresh_token': 'refresh-token'};
    final storage = _MockSecureStorage();
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((call) async => tokens[call.namedArguments[#key]]);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((call) async {
      tokens[call.namedArguments[#key] as String] = call.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((call) async => tokens.remove(call.namedArguments[#key]));

    apiClient = ApiClient(tokenStorage: TokenStorage(storage: storage));
    vocabularyService = VocabularyService(apiClient);
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

  test('목록 조회는 child_profile_id/page/limit을 쿼리로 보내고 items·pagination을 읽는다', () async {
    Uri? uri;
    handler = (request) async {
      uri = request.uri;
      await respond(request, 200, {
        'success': true,
        'data': {
          'items': [
            {
              'vocabulary_entry_id': 10,
              'child_profile_id': 3,
              'english_word': 'castle',
              'korean_meaning': '성, 대저택',
              'is_favorite': false,
              'created_at': '2026-08-12T01:23:45.000Z',
            },
          ],
          'pagination': {'page': 1, 'limit': 20, 'totalCount': 1, 'totalPages': 1},
        },
      });
    };

    final result = await vocabularyService.fetchEntries(3, page: 1, limit: 20);

    expect(uri?.path, '/api/vocabulary');
    expect(uri?.queryParameters, {'child_profile_id': '3', 'page': '1', 'limit': '20'});
    expect(result.items.single.englishWord, 'castle');
    expect(result.totalCount, 1);
  });

  test('저장은 필수 필드와 선택 필드를 함께 보내고 entry를 읽는다', () async {
    Map<String, dynamic>? sentBody;
    handler = (request) async {
      final raw = await utf8.decoder.bind(request).join();
      sentBody = jsonDecode(raw) as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'data': {
          'entry': {
            'vocabulary_entry_id': 1,
            'child_profile_id': 3,
            'story_id': 5,
            'english_word': 'magic',
            'korean_meaning': '마법',
            'is_favorite': false,
            'created_at': '2026-08-12T01:23:45.000Z',
          },
        },
      });
    };

    final entry = await vocabularyService.saveEntry(
      childProfileId: 3,
      storyId: 5,
      englishWord: 'magic',
      koreanMeaning: '마법',
    );

    expect(sentBody, {
      'child_profile_id': 3,
      'story_id': 5,
      'english_word': 'magic',
      'korean_meaning': '마법',
    });
    expect(entry.englishWord, 'magic');
  });

  test('story_id와 example_sentence가 없으면 요청 바디에서도 빠진다', () async {
    Map<String, dynamic>? sentBody;
    handler = (request) async {
      final raw = await utf8.decoder.bind(request).join();
      sentBody = jsonDecode(raw) as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'data': {
          'entry': {
            'vocabulary_entry_id': 1,
            'child_profile_id': 3,
            'english_word': 'magic',
            'korean_meaning': '마법',
            'created_at': '2026-08-12T01:23:45.000Z',
          },
        },
      });
    };

    await vocabularyService.saveEntry(childProfileId: 3, englishWord: 'magic', koreanMeaning: '마법');

    expect(sentBody?.keys, isNot(contains('story_id')));
    expect(sentBody?.keys, isNot(contains('example_sentence')));
  });

  test('삭제는 경로에 id, 쿼리에 child_profile_id를 보낸다', () async {
    String? path;
    Map<String, String>? query;
    handler = (request) async {
      path = request.uri.path;
      query = request.uri.queryParameters;
      await respond(request, 200, {
        'success': true,
        'data': {'deleted': true},
      });
    };

    await vocabularyService.deleteEntry(10, 3);

    expect(path, '/api/vocabulary/10');
    expect(query, {'child_profile_id': '3'});
  });

  test('소유하지 않은 단어를 삭제하면 404를 ApiException으로 전한다', () async {
    handler = (request) async {
      await respond(request, 404, {'success': false, 'message': '단어를 찾을 수 없습니다.'});
    };

    await expectLater(
      vocabularyService.deleteEntry(999, 3),
      throwsA(isA<ApiException>().having((e) => e.statusCode, '상태 코드', 404)),
    );
  });
}
