import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/page_result.dart';
import '../models/json_parse.dart';
import '../models/story.dart';

/// 서버가 생성 작업을 실패로 확정했다. 같은 키로 다시 제출해도 실패가 재생된다.
class StoryGenerationFailedException extends ApiException {
  const StoryGenerationFailedException(String message)
    : super(message: message);
}

/// 동화 생성·조회·삭제·즐겨찾기. (P-SG01~05, P-LB01~05)
///
/// 계약은 Hanium-back `story.router.js`·`storyLibrary.*`·`storyFavorite.controller.js`
/// 기준.
class StoryService {
  final ApiClient _apiClient;
  final Duration _pollInterval;
  final Duration _pollTimeout;

  StoryService(
    this._apiClient, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration pollTimeout = const Duration(minutes: 5),
  }) : _pollInterval = pollInterval,
       _pollTimeout = pollTimeout;

  /// POST /api/stories → 202 작업 접수 → 상태 조회 → 상세 조회.
  ///
  /// 응답을 못 받은 요청을 재시도해도 중복 생성되지 않도록 같은 [requestId]를 보낸다.
  /// 백엔드가 실패 상태로 확정한 작업은 새 요청 ID로 다시 시작해야 한다.
  ///
  /// [imageStyle](그림체 칩 라벨, 서버 50자↓)·[keyword](상세 이야기, 서버 500자↓)는
  /// 선택값이라 공백뿐이면 보내지 않는다(back#40 6번).
  Future<StoryDetail> createStory({
    required int childProfileId,
    required int characterId,
    required String background,
    required String mainEvent,
    required String requestId,
    int? childAge,
    String? imageStyle,
    String? keyword,
  }) async {
    final style = imageStyle?.trim() ?? '';
    final detail = keyword?.trim() ?? '';
    var job = await _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/stories',
        data: {
          'childProfileId': childProfileId,
          'characterId': characterId,
          'background': background,
          'mainEvent': mainEvent,
          if (childAge != null) 'childAge': childAge,
          if (style.isNotEmpty) 'imageStyle': style,
          if (detail.isNotEmpty) 'keyword': detail,
        },
        options: Options(headers: {'Idempotency-Key': requestId}),
      ),
      ApiResponse.data,
    );
    final jobId = parseId(job['jobId']);
    if (jobId < 1) {
      throw const ApiException(message: '동화 생성 작업 응답이 올바르지 않아요.');
    }

    final deadline = DateTime.now().add(_pollTimeout);
    while (true) {
      switch (job['status']) {
        case 'completed':
          final storyId = parseId(job['storyId']);
          if (storyId < 1) {
            throw const ApiException(message: '완료된 동화의 ID가 올바르지 않아요.');
          }
          return fetchStory(childProfileId: childProfileId, storyId: storyId);
        case 'failed':
          throw StoryGenerationFailedException(
            job['errorMessage'] is String
                ? job['errorMessage'] as String
                : '동화 생성에 실패했어요. 다시 만들어 주세요.',
          );
        case 'pending':
        case 'processing':
          if (DateTime.now().isAfter(deadline)) {
            throw const ApiException(
              message: '동화를 계속 만들고 있어요. 잠시 후 다시 시도하면 같은 작업을 확인할 수 있어요.',
            );
          }
          await Future<void>.delayed(_pollInterval);
          job = await _call(
            () => _apiClient.dio.get<Map<String, dynamic>>(
              '/stories/generations/$jobId',
            ),
            ApiResponse.data,
          );
          continue;
        default:
          throw const ApiException(message: '동화 생성 작업 상태가 올바르지 않아요.');
      }
    }
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

  /// GET /api/stories/:id?child_profile_id= → data { storyId, title, character, setting, coverImageUrl, pages, choices }
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
