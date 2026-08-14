import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/child_profile.dart';

/// 자녀 프로필 CRUD. (P-AU-AU04)
///
/// 백엔드 경로는 `/api/children`이다. 계약은 Hanium-back `docs/API_SPEC_PROFILE.md` 기준.
class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  /// GET /api/children → data.profiles
  /// 로그인한 보호자 소유의 프로필만 생성순으로 온다.
  Future<List<ChildProfile>> fetchProfiles() {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>('/children'),
      (response) => ApiResponse.list(
        response,
        'profiles',
      ).map(ChildProfile.fromJson).toList(),
    );
  }

  /// POST /api/children → data.profile
  ///
  /// 첫 프로필은 서버가 자동으로 활성(`is_active: true`)으로 만들고,
  /// 두 번째부터는 비활성으로 생성된다. 전환은 [activateProfile]로만 가능하다.
  Future<ChildProfile> createProfile(ChildProfile draft) {
    return _writeProfile(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/children',
        data: draft.toRequestJson(),
      ),
    );
  }

  /// PUT /api/children/:id → data.profile
  /// 허용 필드만 반영되고, 반영할 필드가 하나도 없으면 서버가 400을 낸다.
  Future<ChildProfile> updateProfile(ChildProfile profile) {
    return _writeProfile(
      () => _apiClient.dio.put<Map<String, dynamic>>(
        '/children/${profile.childProfileId}',
        data: profile.toRequestJson(),
      ),
    );
  }

  /// DELETE /api/children/:id
  Future<void> deleteProfile(int childProfileId) async {
    await _call(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/children/$childProfileId',
      ),
      (_) => null,
    );
  }

  /// PATCH /api/children/:id/activate → data.profile
  /// 한 보호자에게 활성 프로필은 항상 최대 1개다.
  Future<ChildProfile> activateProfile(int childProfileId) {
    return _writeProfile(
      () => _apiClient.dio.patch<Map<String, dynamic>>(
        '/children/$childProfileId/activate',
      ),
    );
  }

  Future<ChildProfile> _writeProfile(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) {
    return _call(
      request,
      (response) => ChildProfile.fromJson(
        ApiResponse.nested(response, 'profile'),
      ),
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
