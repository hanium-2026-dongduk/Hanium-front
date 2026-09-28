import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/story_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 동화 서비스(#39)가 서버 계약대로 요청하고 응답을 읽는지 본다.
void main() {
  late HttpServer server;
  late StoryService storyService;
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

    storyService = StoryService(
      ApiClient(tokenStorage: TokenStorage(storage: storage)),
      pollInterval: Duration.zero,
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

  test('createStory는 요청 키로 작업을 접수하고 완료 후 상세를 조회한다', () async {
    String? method;
    String? path;
    String? requestId;
    Map<String, dynamic>? body;
    var polls = 0;
    handler = (request) async {
      if (request.uri.path == '/api/stories' && request.method == 'POST') {
        method = request.method;
        path = request.uri.path;
        requestId = request.headers.value('Idempotency-Key');
        body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        await respond(request, 202, {
          'success': true,
          'data': {'jobId': 7, 'status': 'pending', 'storyId': null},
        });
        return;
      }
      if (request.uri.path == '/api/stories/generations/7') {
        polls++;
        await respond(request, 200, {
          'success': true,
          'data': {
            'jobId': 7,
            'status': polls == 1 ? 'processing' : 'completed',
            'storyId': polls == 1 ? null : 42,
          },
        });
        return;
      }
      expect(request.uri.path, '/api/stories/42');
      expect(request.uri.queryParameters['child_profile_id'], '3');
      await respond(request, 200, {
        'success': true,
        'data': {
          'character': '토끼',
          'setting': {'background': '신비로운 숲', 'mainEvent': '숨겨진 보물 찾기'},
          'storyId': 42,
          'title': 'The Rabbit Adventure',
          'pages': [
            {
              'pageNumber': 2,
              'content': 'page two',
              'imageUrl': '/images/2.png',
              'audioUrl': '/audio/2.wav',
            },
            {
              'pageNumber': 1,
              'content': 'page one',
              'imageUrl': '/images/1.png',
              'audioUrl': '/audio/1.wav',
            },
          ],
          'choices': ['간다', '멈춘다'],
        },
      });
    };

    final result = await storyService.createStory(
      childProfileId: 3,
      characterId: 9,
      background: '신비로운 숲',
      mainEvent: '숨겨진 보물 찾기',
      childAge: 6,
      requestId: 'request-1',
    );

    expect(method, 'POST');
    expect(path, '/api/stories');
    expect(requestId, 'request-1');
    expect(polls, 2);
    expect(body, {
      'childProfileId': 3,
      'characterId': 9,
      'background': '신비로운 숲',
      'mainEvent': '숨겨진 보물 찾기',
      'childAge': 6,
    });
    expect(result.storyId, 42);
    expect(result.title, 'The Rabbit Adventure');
    // 응답 순서가 뒤죽박죽이어도 pageNumber 기준으로 정렬돼야 한다.
    expect(result.pages.map((p) => p.pageNumber), [1, 2]);
    expect(result.pages.first.content, 'page one');
    expect(result.characterName, '토끼');
    expect(result.background, '신비로운 숲');
    expect(result.choices, ['간다', '멈춘다']);
  });

  test('createStory가 500이면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 500, {'message': '이미지 생성 실패'});
    };

    await expectLater(
      storyService.createStory(
        childProfileId: 3,
        characterId: 9,
        background: '신비로운 숲',
        mainEvent: '숨겨진 보물 찾기',
        requestId: 'request-2',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', '이미지 생성 실패'),
      ),
    );
  });

  test('상태 조회가 실패한 뒤 같은 키로 재시도하면 기존 작업을 이어받는다', () async {
    final requestIds = <String?>[];
    var statusCalls = 0;
    handler = (request) async {
      if (request.method == 'POST') {
        requestIds.add(request.headers.value('Idempotency-Key'));
        await respond(request, 202, {
          'success': true,
          'data': {
            'jobId': 7,
            'status': requestIds.length == 1 ? 'pending' : 'completed',
            'storyId': requestIds.length == 1 ? null : 42,
          },
        });
      } else if (request.uri.path.endsWith('/generations/7')) {
        statusCalls++;
        await respond(request, 503, {'success': false, 'message': '일시적인 오류'});
      } else {
        await respond(request, 200, {
          'success': true,
          'data': {'storyId': 42, 'title': '완료', 'pages': []},
        });
      }
    };

    Future<void> run() async {
      await storyService.createStory(
        childProfileId: 3,
        characterId: 9,
        background: '숲',
        mainEvent: '탐험',
        requestId: 'same-request',
      );
    }

    await expectLater(run(), throwsA(isA<ApiException>()));
    await run();
    expect(requestIds, ['same-request', 'same-request']);
    expect(statusCalls, 1);
  });

  test('서버가 작업 실패를 확정하면 재시도용 예외를 반환한다', () async {
    handler = (request) async {
      await respond(request, 202, {
        'success': true,
        'data': {
          'jobId': 7,
          'status': 'failed',
          'storyId': null,
          'errorMessage': 'AI 생성 실패',
        },
      });
    };

    await expectLater(
      storyService.createStory(
        childProfileId: 3,
        characterId: 9,
        background: '숲',
        mainEvent: '탐험',
        requestId: 'failed-request',
      ),
      throwsA(
        isA<StoryGenerationFailedException>().having(
          (error) => error.message,
          'message',
          'AI 생성 실패',
        ),
      ),
    );
  });

  test('fetchStories는 favoriteOnly가 false면 favorite 쿼리를 아예 보내지 않는다', () async {
    Map<String, String>? query;
    handler = (request) async {
      query = request.uri.queryParameters;
      await respond(request, 200, {
        'success': true,
        'data': {
          'items': [
            {
              'storyId': 1,
              'title': 'A',
              'isFavorite': false,
              'createdAt': '2026-09-01T00:00:00.000Z',
            },
          ],
          'pagination': {
            'page': 1,
            'limit': 20,
            'totalCount': 1,
            'totalPages': 1,
          },
        },
      });
    };

    final result = await storyService.fetchStories(childProfileId: 3);

    expect(query!.containsKey('favorite'), isFalse);
    expect(query!['child_profile_id'], '3');
    expect(query!['sort'], 'latest');
    expect(result.items, hasLength(1));
    expect(result.items.single.storyId, 1);
    expect(result.items.single.createdAt, isNotNull);
  });

  test('fetchStories(favoriteOnly: true)는 favorite=true 쿼리를 보낸다', () async {
    Map<String, String>? query;
    handler = (request) async {
      query = request.uri.queryParameters;
      await respond(request, 200, {
        'success': true,
        'data': {
          'items': <Map<String, dynamic>>[],
          'pagination': {
            'page': 1,
            'limit': 20,
            'totalCount': 0,
            'totalPages': 1,
          },
        },
      });
    };

    await storyService.fetchStories(childProfileId: 3, favoriteOnly: true);

    expect(query!['favorite'], 'true');
  });

  test('fetchStory는 child_profile_id 쿼리로 GET한다', () async {
    String? path;
    String? childQuery;
    handler = (request) async {
      path = request.uri.path;
      childQuery = request.uri.queryParameters['child_profile_id'];
      await respond(request, 200, {
        'success': true,
        'data': {
          'storyId': 42,
          'title': 'T',
          'pages': <Map<String, dynamic>>[],
          'character': '토끼',
          'setting': {'background': '숲', 'mainEvent': '탐험'},
          'choices': ['계속 걷기'],
        },
      });
    };

    final result = await storyService.fetchStory(
      childProfileId: 3,
      storyId: 42,
    );

    expect(path, '/api/stories/42');
    expect(childQuery, '3');
    expect(result.storyId, 42);
    expect(result.pages, isEmpty);
    expect(result.characterName, '토끼');
    expect(result.choices, ['계속 걷기']);
  });

  test('deleteStory는 DELETE로 요청한다', () async {
    String? method;
    String? path;
    handler = (request) async {
      method = request.method;
      path = request.uri.path;
      await respond(request, 200, {
        'success': true,
        'data': {'deleted': true},
      });
    };

    await storyService.deleteStory(childProfileId: 3, storyId: 42);

    expect(method, 'DELETE');
    expect(path, '/api/stories/42');
  });

  test('addFavorite은 body에 child_profile_id·story_id를 담아 POST한다', () async {
    Map<String, dynamic>? body;
    handler = (request) async {
      body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'data': {'alreadyFavorited': false},
      });
    };

    await storyService.addFavorite(childProfileId: 3, storyId: 42);

    expect(body, {'child_profile_id': 3, 'story_id': 42});
  });

  test('removeFavorite은 쿼리가 아니라 body에 child_profile_id를 담는다', () async {
    Map<String, dynamic>? body;
    String? query;
    handler = (request) async {
      query = request.uri.query;
      body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      await respond(request, 200, {
        'success': true,
        'data': {'removed': true},
      });
    };

    await storyService.removeFavorite(childProfileId: 3, storyId: 42);

    expect(query, isEmpty);
    expect(body, {'child_profile_id': 3});
  });
}
