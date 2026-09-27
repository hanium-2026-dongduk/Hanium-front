import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/models/character.dart';
import 'package:hanium_front/services/character_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 캐릭터 서비스(#39)가 서버 계약대로 요청하고 응답을 읽는지 본다.
void main() {
  late HttpServer server;
  late CharacterService characterService;
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

    characterService = CharacterService(
      ApiClient(tokenStorage: TokenStorage(storage: storage)),
    );
    server.listen((request) async => handler(request));
  });

  tearDown(() async {
    await server.close(force: true);
    dotenv.clean();
  });

  Future<void> respond(HttpRequest request, int statusCode, Object body) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  test('fetchCharacters는 data가 배열인 응답을 그대로 읽는다', () async {
    String? path;
    handler = (request) async {
      path = request.uri.path;
      await respond(request, 200, {
        'success': true,
        'data': [
          {
            'character_id': 1,
            'name': '토끼',
            'personality': '용감함',
            'description': '설명',
            'image_url': null,
            'type': 'CUSTOM',
          },
        ],
      });
    };

    final result = await characterService.fetchCharacters();

    expect(path, '/api/characters');
    expect(result, hasLength(1));
    expect(result.single.characterId, 1);
    expect(result.single.name, '토끼');
    expect(result.single.type, CharacterType.custom);
  });

  test('fetchCharacters는 data가 없으면 빈 목록을 준다', () async {
    handler = (request) async {
      await respond(request, 200, {'success': true, 'data': <Object>[]});
    };

    final result = await characterService.fetchCharacters();

    expect(result, isEmpty);
  });

  test('createCharacter는 camelCase 본문으로 POST하고 생성된 캐릭터를 읽는다', () async {
    String? method;
    Map<String, dynamic>? body;
    handler = (request) async {
      method = request.method;
      body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'message': '캐릭터가 생성되었습니다.',
        'data': {
          'character_id': 5,
          'name': '뽀로로',
          'personality': '용감하고 호기심이 많아요',
          'description': '설명',
          'image_url': null,
          'type': 'RANDOM',
        },
      });
    };

    final result = await characterService.createCharacter(
      name: '뽀로로',
      personality: '용감하고 호기심이 많아요',
      description: '설명',
      type: CharacterType.random,
    );

    expect(method, 'POST');
    expect(body, {
      'name': '뽀로로',
      'personality': '용감하고 호기심이 많아요',
      'description': '설명',
      'type': 'RANDOM',
    });
    expect(result.characterId, 5);
    expect(result.type, CharacterType.random);
  });

  test('createCharacter가 이름 누락으로 400이면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 400, {'message': '캐릭터 이름은 필수입니다.'});
    };

    await expectLater(
      characterService.createCharacter(name: ''),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', '캐릭터 이름은 필수입니다.'),
      ),
    );
  });
}
