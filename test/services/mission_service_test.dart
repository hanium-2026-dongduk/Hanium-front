import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/models/daily_mission.dart';
import 'package:hanium_front/services/mission_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 미션 서비스(RW01)가 카탈로그·진행 상황을 서버 계약대로 읽는지 본다.
void main() {
  late HttpServer server;
  late ApiClient apiClient;
  late MissionService missionService;
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
    missionService = MissionService(apiClient);
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

  test('카탈로그는 /missions를 부르고 카탈로그 순서를 그대로 읽는다', () async {
    String? path;
    handler = (request) async {
      path = request.uri.path;
      await respond(request, 200, {
        'success': true,
        'data': {
          'missions': [
            {'missionType': 'attendance', 'targetCount': 1, 'rewardPoints': 10},
            {'missionType': 'story_read', 'targetCount': 1, 'rewardPoints': 20},
          ],
        },
      });
    };

    final missions = await missionService.fetchCatalog();

    expect(path, '/api/missions');
    expect(missions.map((m) => m.type), [MissionType.attendance, MissionType.storyRead]);
  });

  test('오늘의 진행 상황은 childId를 경로에 넣고 status를 읽는다', () async {
    String? path;
    handler = (request) async {
      path = request.uri.path;
      await respond(request, 200, {
        'success': true,
        'data': {
          'missionDate': '2026-08-12',
          'missions': [
            {'missionType': 'attendance', 'targetCount': 1, 'progressCount': 1, 'rewardPoints': 10, 'status': 'rewarded'},
            {'missionType': 'word_clicked', 'targetCount': 5, 'progressCount': 2, 'rewardPoints': 15, 'status': 'pending'},
          ],
        },
      });
    };

    final missions = await missionService.fetchProgress(7);

    expect(path, '/api/missions/progress/7');
    expect(missions[0].status, MissionStatus.rewarded);
    expect(missions[1].progressCount, 2);
    expect(missions[1].status.isDone, isFalse);
  });
}
