import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/attendance_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 출석 서비스(RW02)가 체크·월간 현황을 서버 계약대로 다루는지 본다.
void main() {
  late HttpServer server;
  late ApiClient apiClient;
  late AttendanceService attendanceService;
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
    attendanceService = AttendanceService(apiClient);
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

  test('출석 체크는 body에 child_profile_id를 담고 pointsEarned를 읽는다', () async {
    String? path;
    Map<String, dynamic>? sentBody;
    handler = (request) async {
      path = request.uri.path;
      final raw = await utf8.decoder.bind(request).join();
      sentBody = jsonDecode(raw) as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'data': {
          'attendanceDate': '2026-08-12',
          'alreadyChecked': false,
          'streakDays': 3,
          'pointsEarned': 30,
          'badgesAwarded': <String>[],
        },
      });
    };

    final result = await attendanceService.checkIn(7);

    expect(path, '/api/attendance/check');
    expect(sentBody, {'child_profile_id': 7});
    expect(result.pointsEarned, 30);
    expect(result.streakDays, 3);
  });

  test('같은 날 재요청이면 alreadyChecked가 true다 (200이어도 오류가 아니다)', () async {
    handler = (request) async {
      await respond(request, 200, {
        'success': true,
        'data': {
          'attendanceDate': '2026-08-12',
          'alreadyChecked': true,
          'streakDays': 3,
          'pointsEarned': 0,
        },
      });
    };

    final result = await attendanceService.checkIn(7);

    expect(result.alreadyChecked, isTrue);
    expect(result.pointsEarned, 0);
  });

  test('월간 현황은 childId를 경로에, month를 쿼리에 담는다', () async {
    String? path;
    Map<String, String>? query;
    handler = (request) async {
      path = request.uri.path;
      query = request.uri.queryParameters;
      await respond(request, 200, {
        'success': true,
        'data': {
          'childProfileId': 7,
          'month': '2026-08',
          'attendedDates': ['2026-08-01'],
          'attendedCount': 1,
          'denominator': 12,
          'attendanceRate': 8.3,
          'currentStreak': 1,
        },
      });
    };

    final month = await attendanceService.fetchMonthly(7, month: '2026-08');

    expect(path, '/api/attendance/7');
    expect(query, {'month': '2026-08'});
    expect(month.currentStreak, 1);
  });

  test('month를 생략하면 쿼리 파라미터 없이 요청한다', () async {
    Map<String, String>? query;
    handler = (request) async {
      query = request.uri.queryParameters;
      await respond(request, 200, {
        'success': true,
        'data': {
          'childProfileId': 7,
          'month': '2026-08',
          'attendedDates': <String>[],
          'attendedCount': 0,
          'denominator': 12,
          'attendanceRate': 0.0,
          'currentStreak': 0,
        },
      });
    };

    await attendanceService.fetchMonthly(7);

    expect(query, isEmpty);
  });
}
