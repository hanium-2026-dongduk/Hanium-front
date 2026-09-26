import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/quiz.dart';

/// 동화 확인 퀴즈 생성·조회·제출. (P-ED-QZ01, P-ED-QZ03)
///
/// 계약은 Hanium-back `quiz.route.js`·`quiz.controller.js` 기준이다.
///
/// 이 서비스가 **일부러 부르지 않는 API**
/// - `GET /quizzes/attempts`: page/limit 쿼리가 문자열로 넘어가 깨질 수 있다.
/// - 라이브러리에서 기존 퀴즈를 다시 여는 API는 없다. `generate`를 다시 부르면
///   같은 동화의 문항이 교체되므로 "다시 열기" 용도로 쓰면 안 된다.
class QuizService {
  final ApiClient _apiClient;

  QuizService(this._apiClient);

  /// Gemini가 재시도까지 하며 만들기 때문에 기본 수신 제한(10초)으로는 모자랄 수 있다.
  static const Duration _generateTimeout = Duration(seconds: 45);

  /// POST /api/quizzes/generate → 201 data { quizSetId, status, questionCount }
  ///
  /// 동화가 없거나 내 자녀 것이 아니면 404, Gemini 실패는 502다.
  /// 같은 동화로 다시 부르면 서버가 문항을 새로 만들어 교체한다.
  Future<QuizGeneration> generate({required int childProfileId, required int storyId}) {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/quizzes/generate',
        data: {'child_profile_id': childProfileId, 'story_id': storyId},
        options: Options(receiveTimeout: _generateTimeout),
      ),
      (response) => QuizGeneration.fromJson(ApiResponse.data(response)),
    );
  }

  /// GET /api/quizzes/:id?child_profile_id= → data { quizSetId, status, questions }
  /// 정답 여부는 들어 있지 않다.
  Future<QuizSet> fetchQuiz({required int childProfileId, required int quizSetId}) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/quizzes/$quizSetId',
        queryParameters: {'child_profile_id': childProfileId},
      ),
      (response) => QuizSet.fromJson(ApiResponse.data(response)),
    );
  }

  /// POST /api/quizzes/:id/submit → 201 data { attemptId, ..., pointsEarned, leveledUp, badgesAwarded }
  ///
  /// **같은 퀴즈를 다시 제출하면 서버가 포인트를 또 준다.** 그래서 재제출은
  /// 호출하는 쪽(QuizProvider)이 막아야 한다.
  /// [answers]는 문항 id → 고른 보기 id.
  Future<QuizResult> submit({
    required int childProfileId,
    required int quizSetId,
    required Map<int, int> answers,
  }) {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/quizzes/$quizSetId/submit',
        data: {
          'child_profile_id': childProfileId,
          'answers': [
            for (final entry in answers.entries)
              {'questionId': entry.key, 'selectedOptionId': entry.value},
          ],
        },
      ),
      (response) => QuizResult.fromJson(ApiResponse.data(response)),
    );
  }

  Future<T> _call<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Response<Map<String, dynamic>> response) parse,
  ) async {
    try {
      return parse(await request());
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
