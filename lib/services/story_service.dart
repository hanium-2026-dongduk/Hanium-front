import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/page_result.dart';
import '../models/story.dart';

/// 동화 생성·조회·삭제·즐겨찾기. (P-SG01~05, P-LB01~05)
///
/// 계약은 Hanium-back `story.router.js`·`storyLibrary.*`·`storyFavorite.controller.js`
/// 기준. 그림체(imageStyle)·키워드 필드는 아직 백엔드에 없어(카톡으로 별도 협의,
/// back#40 6번) 요청에 넣지 않는다.
class StoryService {
  final ApiClient _apiClient;

  StoryService(this._apiClient);

  /// 텍스트 생성 후 페이지마다 이미지·TTS를 순서대로 만들어 기본 수신 제한(10초)으로는
  /// 모자라다. 운영 Nginx는 60초 제한이라 그래도 504가 날 수 있어 별도로 요청해뒀다
  /// (back#40 1번).
  static const Duration _createTimeout = Duration(seconds: 120);

  /// POST /api/stories → 201 data { character, setting, storyId, title, pages[], choices[] }
  ///
  /// 캐릭터를 찾을 수 없으면 404, 배경/사건이 비어 있으면 400, AI 생성 실패는 500이다.
  Future<StoryDetail> createStory({
    required int childProfileId,
    required int characterId,
    required String background,
    required String mainEvent,
    int? childAge,
  }) {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/stories',
        data: {
          'childProfileId': childProfileId,
          'characterId': characterId,
          'background': background,
          'mainEvent': mainEvent,
          if (childAge != null) 'childAge': childAge,
        },
        options: Options(receiveTimeout: _createTimeout),
      ),
      (response) => StoryDetail.fromJson(ApiResponse.data(response)),
    );
  }

  /// GET /api/stories?child_profile_id&sort&favorite&page&limit → { items, pagination }
  ///
  /// [favoriteOnly]가 false면 `favorite` 파라미터를 아예 보내지 않는다. 서버가
  /// Express 5라 `favorite=false`도 문자열 그대로 참으로 읽어 즐겨찾기만
  /// 걸러버리기 때문이다.
  Future<PageResult<StorySummary>> fetchStories({
    required int childProfileId,
    String sort = 'latest',
    bool favoriteOnly = false,
    int page = 1,
    int limit = 20,
  }) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/stories',
        queryParameters: {
          'child_profile_id': childProfileId,
          'sort': sort,
          if (favoriteOnly) 'favorite': true,
          'page': page,
          'limit': limit,
        },
      ),
      (response) => PageResult.fromJson(
        ApiResponse.data(response),
        StorySummary.fromJson,
      ),
    );
  }

  /// GET /api/stories/:id?child_profile_id= → data { storyId, title, pages }
  /// 소유하지 않았고 공개도 아니면 404.
  Future<StoryDetail> fetchStory({
    required int childProfileId,
    required int storyId,
  }) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/stories/$storyId',
        queryParameters: {'child_profile_id': childProfileId},
      ),
      (response) => StoryDetail.fromJson(ApiResponse.data(response)),
    );
  }

  /// DELETE /api/stories/:id?child_profile_id= — 소유하지 않았으면 404.
  Future<void> deleteStory({
    required int childProfileId,
    required int storyId,
  }) async {
    await _call(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/stories/$storyId',
        queryParameters: {'child_profile_id': childProfileId},
      ),
      (_) => null,
    );
  }

  /// POST /api/favorites { child_profile_id, story_id }
  Future<void> addFavorite({
    required int childProfileId,
    required int storyId,
  }) async {
    await _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/favorites',
        data: {'child_profile_id': childProfileId, 'story_id': storyId},
      ),
      (_) => null,
    );
  }

  /// DELETE /api/favorites/:storyId — child_profile_id는 쿼리가 아니라 body에 담아야 한다.
  Future<void> removeFavorite({
    required int childProfileId,
    required int storyId,
  }) async {
    await _call(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/favorites/$storyId',
        data: {'child_profile_id': childProfileId},
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
