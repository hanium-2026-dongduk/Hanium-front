import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/badge_status.dart';

/// 배지 조회. (P-GM-RW04, P-MY-MP02)
///
/// 배지는 서버가 조건 달성 시 자동으로 부여하므로 조회만 있다.
/// 응답 필드는 다른 보상 API와 달리 snake_case다.
class BadgeService {
  final ApiClient _apiClient;

  BadgeService(this._apiClient);

  /// GET /api/badges/:childId → 전체 배지와 획득 여부
  Future<BadgeSummary> fetchChildBadges(int childProfileId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/badges/$childProfileId');
      return BadgeSummary.fromJson(ApiResponse.data(response));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
