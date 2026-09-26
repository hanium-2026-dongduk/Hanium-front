import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_client.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/core/token_storage.dart';
import 'package:hanium_front/services/quiz_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 퀴즈 서비스(QZ01·QZ03)가 서버 계약대로 요청하고 응답을 읽는지 본다.
void main() {
  late HttpServer server;
  late QuizService quizService;
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

    quizService = QuizService(ApiClient(tokenStorage: TokenStorage(storage: storage)));
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

  test('generate는 snake_case 본문으로 POST하고 quizSetId를 읽는다', () async {
    String? method;
    String? path;
    Map<String, dynamic>? body;
    handler = (request) async {
      method = request.method;
      path = request.uri.path;
      body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'data': {'quizSetId': '7', 'status': 'ready', 'questionCount': 5},
      });
    };

    final result = await quizService.generate(childProfileId: 3, storyId: 11);

    expect(method, 'POST');
    expect(path, '/api/quizzes/generate');
    expect(body, {'child_profile_id': 3, 'story_id': 11});
    expect(result.quizSetId, 7);
    expect(result.status, 'ready');
    expect(result.questionCount, 5);
  });

  test('generate가 502면 서버 메시지를 담은 ApiException을 던진다', () async {
    handler = (request) async {
      await respond(request, 502, {'message': '퀴즈 생성에 실패했습니다. 다시 시도해주세요.'});
    };

    await expectLater(
      quizService.generate(childProfileId: 3, storyId: 11),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.message, 'message', '퀴즈 생성에 실패했습니다. 다시 시도해주세요.'),
      ),
    );
  });

  test('fetchQuiz는 child_profile_id 쿼리로 GET하고 문항·보기를 순서대로 읽는다', () async {
    String? path;
    String? childQuery;
    handler = (request) async {
      path = request.uri.path;
      childQuery = request.uri.queryParameters['child_profile_id'];
      await respond(request, 200, {
        'success': true,
        'data': {
          'quizSetId': 7,
          'status': 'ready',
          'questions': [
            {
              'questionId': 101,
              'questionOrder': 1,
              'questionText': 'Where did the bunny go?',
              'options': [
                {'optionId': 1001, 'optionOrder': 1, 'optionText': 'Candy Forest'},
                {'optionId': 1002, 'optionOrder': 2, 'optionText': 'Cookie Castle'},
              ],
            },
          ],
        },
      });
    };

    final quiz = await quizService.fetchQuiz(childProfileId: 3, quizSetId: 7);

    expect(path, '/api/quizzes/7');
    expect(childQuery, '3');
    expect(quiz.quizSetId, 7);
    expect(quiz.questions, hasLength(1));
    expect(quiz.questions.single.text, 'Where did the bunny go?');
    expect(quiz.questions.single.options.map((o) => o.optionId), [1001, 1002]);
    expect(quiz.questions.single.options.first.text, 'Candy Forest');
  });

  test('submit은 answers 배열로 POST하고 채점 결과·보상을 읽는다', () async {
    String? path;
    Map<String, dynamic>? body;
    handler = (request) async {
      path = request.uri.path;
      body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      await respond(request, 201, {
        'success': true,
        'data': {
          'attemptId': 55,
          'totalQuestions': 2,
          'correctCount': 1,
          'score': 50,
          'answers': [
            {
              'questionId': 101,
              'selectedOptionId': 1001,
              'correctOptionId': 1001,
              'isCorrect': true,
            },
            {
              'questionId': 102,
              'selectedOptionId': 1005,
              'correctOptionId': 1006,
              'isCorrect': false,
            },
          ],
          'pointsEarned': 5,
          'leveledUp': true,
          'badgesAwarded': ['first_quiz'],
        },
      });
    };

    final result = await quizService.submit(
      childProfileId: 3,
      quizSetId: 7,
      answers: {101: 1001, 102: 1005},
    );

    expect(path, '/api/quizzes/7/submit');
    expect(body, {
      'child_profile_id': 3,
      'answers': [
        {'questionId': 101, 'selectedOptionId': 1001},
        {'questionId': 102, 'selectedOptionId': 1005},
      ],
    });
    expect(result.attemptId, 55);
    expect(result.correctCount, 1);
    expect(result.score, 50);
    expect(result.pointsEarned, 5);
    expect(result.leveledUp, isTrue);
    expect(result.badgesAwarded, ['first_quiz']);
    expect(result.answerFor(102)?.correctOptionId, 1006);
    expect(result.answerFor(102)?.isCorrect, isFalse);
    expect(result.answerFor(999), isNull);
  });
}
