import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/daily_mission.dart';

/// 오늘의 미션 카탈로그·진행 상황. (P-GM-RW01)
///
/// 계약은 Hanium-back `docs/API_SPEC_REWARD.md` 3~4절 기준.
///
/// **이 도메인에는 "보상받기" API가 없다.** 진행도가 목표치에 도달하는 순간
/// 서버가 같은 호출 안에서 자동으로 지급까지 끝낸다. 화면은 진행 상태만 보여준다.
class MissionService {
  final ApiClient _apiClient;

  MissionService(this._apiClient);

  /// GET /api/missions → data.missions
  /// 자녀에 종속되지 않는 정적 카탈로그다. 자유롭게 캐시해도 된다.
  Future<List<DailyMission>> fetchCatalog() {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>('/missions'),
      (response) => ApiResponse.list(response, 'missions').map(DailyMission.fromJson).toList(),
    );
  }

  /// GET /api/missions/progress/:childId → data.missions
  ///
  /// **부작용이 있는 GET이다.** 오늘자 미션 행이 없으면 이 호출이 만든다.
  /// `missions` 배열은 항상 카탈로그 순서로 온다.
  Future<List<DailyMission>> fetchProgress(int childProfileId) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>('/missions/progress/$childProfileId'),
      (response) => ApiResponse.list(response, 'missions').map(DailyMission.fromJson).toList(),
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
