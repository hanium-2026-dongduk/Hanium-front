import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/page_result.dart';
import '../models/vocabulary_entry.dart';
import '../models/word_meaning.dart';

/// 단어장 CRUD와 단어 뜻 조회. (P-ED-VB01, P-ED-VB03)
///
/// 백엔드 경로는 `/api/vocabulary`다. 계약은 Hanium-back
/// `src/routes/vocabulary.route.js`, `src/controllers/vocabulary.controller.js` 기준.
class VocabularyService {
  final ApiClient _apiClient;

  VocabularyService(this._apiClient);

  /// GET /api/vocabulary?child_profile_id&page&limit → { items, pagination }
  /// 최신 저장 순으로 온다.
  Future<PageResult<VocabularyEntry>> fetchEntries(
    int childProfileId, {
    int page = 1,
    int limit = 20,
  }) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/vocabulary',
        queryParameters: {
          'child_profile_id': childProfileId,
          'page': page,
          'limit': limit,
        },
      ),
      (response) => PageResult.fromJson(
        ApiResponse.data(response),
        VocabularyEntry.fromJson,
      ),
    );
  }

  /// GET /api/vocabulary/lookup?word → { english_word, korean_meaning }
  /// 저장은 하지 않는다. 누른 토큰을 그대로 보내도 서버가 앞뒤 문장부호를 뗀다.
  /// 뜻을 모르는 단어는 404, 요청이 잦으면 429, AI 호출 실패는 502.
  Future<WordMeaning> lookupMeaning(String word) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/vocabulary/lookup',
        queryParameters: {'word': word},
      ),
      (response) => WordMeaning.fromJson(ApiResponse.data(response)),
    );
  }

  /// POST /api/vocabulary → data.entry
  /// storyId를 함께 보내면 동화 뷰어에서 저장한 단어로 연결된다.
  Future<VocabularyEntry> saveEntry({
    required int childProfileId,
    int? storyId,
    required String englishWord,
    required String koreanMeaning,
    String? exampleSentence,
  }) {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/vocabulary',
        data: {
          'child_profile_id': childProfileId,
          if (storyId != null) 'story_id': storyId,
          'english_word': englishWord,
          'korean_meaning': koreanMeaning,
          if (exampleSentence != null && exampleSentence.isNotEmpty)
            'example_sentence': exampleSentence,
        },
      ),
      (response) =>
          VocabularyEntry.fromJson(ApiResponse.nested(response, 'entry')),
    );
  }

  /// DELETE /api/vocabulary/:id?child_profile_id
  /// 소유하지 않은 단어이거나 이미 삭제됐으면 404.
  Future<void> deleteEntry(int vocabularyEntryId, int childProfileId) async {
    await _call(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/vocabulary/$vocabularyEntryId',
        queryParameters: {'child_profile_id': childProfileId},
      ),
      (_) => null,
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
