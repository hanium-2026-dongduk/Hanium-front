import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/page_result.dart';
import '../models/received_sticker.dart';

/// 칭찬 스티커 조회 및 보호자 스티커 발송 서비스
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

  /// GET /api/stickers → 보호자가 보낼 수 있는 스티커 카탈로그 조회 (PD04)
  Future<Map<String, dynamic>> fetchStickerCatalog() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/stickers');
      // 기존 코드의 컨벤션인 ApiResponse.data()를 활용해 데이터 추출
      return ApiResponse.data(response);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// POST /api/stickers/send → 자녀에게 칭찬 스티커 발송 (PD04)
  Future<void> sendSticker({
    required int childId,
    required String stickerCode,
    String? message,
  }) async {
    try {
      await _apiClient.dio.post(
        '/stickers/send',
        data: {
          'child_profile_id': childId,
          'sticker_code': stickerCode,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
