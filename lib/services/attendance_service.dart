import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/attendance_month.dart';

/// 출석 체크·월간 현황. (P-GM-RW02)
///
/// 계약은 Hanium-back `docs/API_SPEC_REWARD.md` 1~2절 기준.
class AttendanceService {
  final ApiClient _apiClient;

  AttendanceService(this._apiClient);

  /// POST /api/attendance/check → data
  ///
  /// **멱등하다.** 같은 날 몇 번을 호출해도 출석은 한 번만 기록되고 포인트도
  /// 한 번만 지급된다. 앱이 "오늘 이미 호출했는지"를 따로 관리할 필요가 없다.
  Future<AttendanceCheckResult> checkIn(int childProfileId) {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/attendance/check',
        data: {'child_profile_id': childProfileId},
      ),
      (response) => AttendanceCheckResult.fromJson(ApiResponse.data(response)),
    );
  }

  /// GET /api/attendance/:childId?month=YYYY-MM → data
  /// month를 생략하면 서버가 오늘(Asia/Seoul) 기준 당월로 응답한다.
  Future<AttendanceMonth> fetchMonthly(int childProfileId, {String? month}) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/attendance/$childProfileId',
        queryParameters: month != null ? {'month': month} : null,
      ),
      (response) => AttendanceMonth.fromJson(ApiResponse.data(response)),
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
