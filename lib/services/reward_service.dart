import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/json_parse.dart';

/// 보상 포인트 조회. (P-MN-MN02 토큰 표시)
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
  Future<int> fetchPointBalance(int childProfileId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/rewards/$childProfileId/summary',
      );
      return parseId(ApiResponse.data(response)['points']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
