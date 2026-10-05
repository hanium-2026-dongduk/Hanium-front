import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/page_result.dart';
import '../models/received_sticker.dart';

/// 받은 칭찬 스티커 조회. (P-MY-MP05)
///
/// 스티커는 보호자가 보내는 것이라 아이 앱에서는 조회만 있다.
/// 응답 필드는 배지 API처럼 snake_case다.
class StickerService {
  final ApiClient _apiClient;

  StickerService(this._apiClient);

  /// GET /api/stickers/received/:childId?page&limit → 받은 스티커 한 페이지
  Future<PageResult<ReceivedSticker>> fetchReceived(
    int childProfileId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/stickers/received/$childProfileId',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PageResult.fromJson(ApiResponse.data(response), ReceivedSticker.fromJson);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
