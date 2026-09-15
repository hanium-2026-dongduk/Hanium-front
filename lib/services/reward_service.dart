import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/json_parse.dart';
import '../models/page_result.dart';
import '../models/reward_detail.dart';
import '../models/reward_history_entry.dart';

/// 보상 포인트 조회. (P-MN-MN02 토큰 표시, P-GM-RW02~RW04)
///
/// 계약은 Hanium-back `docs/API_SPEC_REWARD.md` 기준이다.
///
/// **"토큰"과 "포인트"는 같은 값이다.** 요구사항 정의서에서 메인 화면은 "토큰",
/// 마이페이지는 "포인트"라고 부를 뿐 백엔드에는 하나의 `points`만 있다.
/// (`docs/WEEK3_A_DESIGN.md` 참고) 그래서 여기서는 서버 필드명 그대로 point를 쓰고,
/// 화면에서 라벨만 골라 쓴다.
class RewardService {
  final ApiClient _apiClient;

  RewardService(this._apiClient);

  /// GET /api/rewards/:childId/summary → data.points
  ///
  /// 메인 화면이 자주 부르는 경량 응답이라 잔액만 돌아온다.
  /// 지갑이 없던 자녀도 서버가 만들어 주므로 0부터 시작한다.
  ///
  /// 자기 자녀가 아니면 404, 토큰이 없으면 401이다.
  Future<int> fetchPointBalance(int childProfileId) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>('/rewards/$childProfileId/summary'),
      (response) => parseId(ApiResponse.data(response)['points']),
    );
  }

  /// GET /api/rewards/:childId → data
  /// 포인트+레벨+연속출석+levelProgress. 마이페이지/보상 현황용. (P-GM-RW02, RW04)
  Future<RewardDetail> fetchDetail(int childProfileId) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>('/rewards/$childProfileId'),
      (response) => RewardDetail.fromJson(ApiResponse.data(response)),
    );
  }

  /// GET /api/rewards/:childId/history?page&limit&reason&from&to → { items, pagination }
  /// (P-GM-RW03) reason을 생략하면 전체 사유가 최신순으로 온다.
  Future<PageResult<RewardHistoryEntry>> fetchHistory(
    int childProfileId, {
    int page = 1,
    int limit = 20,
    String? reason,
  }) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/rewards/$childProfileId/history',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (reason != null) 'reason': reason,
        },
      ),
      (response) => PageResult.fromJson(ApiResponse.data(response), RewardHistoryEntry.fromJson),
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
