import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/dashboard_summary.dart';

/// 학습 대시보드 요약 조회. (P-MY-MP03)
class DashboardService {
  final ApiClient _apiClient;

  DashboardService(this._apiClient);

  /// GET /api/dashboard/:childId → 동화·단어·퀴즈 집계
  Future<DashboardSummary> fetchSummary(int childProfileId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/dashboard/$childProfileId');
      return DashboardSummary.fromJson(ApiResponse.data(response));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
