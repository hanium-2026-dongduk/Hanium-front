import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/usage_summary.dart';

/// 학습(앱 사용) 시간 조회. (P-MY-MP03)
class UsageService {
  final ApiClient _apiClient;

  UsageService(this._apiClient);

  /// GET /api/usage/:childId/summary?from&to → 기간별 누적 사용 시간
  ///
  /// from·to(`YYYY-MM-DD`)를 생략하면 서버가 오늘 포함 최근 7일(Asia/Seoul)로 응답한다.
  Future<UsageSummary> fetchSummary(
    int childProfileId, {
    String? from,
    String? to,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/usage/$childProfileId/summary',
        queryParameters: {'from': ?from, 'to': ?to},
      );
      return UsageSummary.fromJson(ApiResponse.data(response));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
