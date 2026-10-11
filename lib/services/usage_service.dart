import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/usage_summary.dart';

/// 학습(앱 사용) 시간 조회. (P-MY-MP03, 보호자 대시보드)
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

  /// POST /api/usage/heartbeat → 지금까지의 사용 시간을 서버에 누적
  ///
  /// 서버가 직전 heartbeat와의 간격(1회 최대 90초)을 직접 계산하므로 시간 값은 보내지 않는다.
  /// 보호자가 정한 하루 한도를 넘으면 403 [ApiException]을 던진다.
  Future<void> sendHeartbeat(int childProfileId) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/usage/heartbeat',
        data: {'child_profile_id': childProfileId},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> getTodayUsage(int childId) async {
    final response = await _apiClient.dio.get('/api/usage/$childId/today');
    return response.data['data'];
  }
}
