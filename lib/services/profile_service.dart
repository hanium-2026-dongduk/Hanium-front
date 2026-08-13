import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/child_profile.dart';

/// 자녀 프로필 CRUD. (P-AU-AU04 프로필 관리)
class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  /// GET /api/profiles → { "profiles": [...] }
  Future<List<ChildProfile>> fetchProfiles() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/profiles',
      );
      final profiles = response.data?['profiles'] as List<dynamic>? ?? [];
      return profiles
          .map((json) => ChildProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// POST /api/profiles → { "profile": {...} }
  Future<ChildProfile> createProfile({
    required String name,
    DateTime? birthDate,
    String? avatarKey,
  }) {
    final draft = ChildProfile(
      id: 0, // 서버가 채워주므로 요청에는 담기지 않는다.
      name: name,
      birthDate: birthDate,
      avatarKey: avatarKey,
    );
    return _writeProfile(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/profiles',
        data: draft.toRequestJson(),
      ),
    );
  }

  /// PATCH /api/profiles/:id → { "profile": {...} }
  Future<ChildProfile> updateProfile(ChildProfile profile) {
    return _writeProfile(
      () => _apiClient.dio.patch<Map<String, dynamic>>(
        '/profiles/${profile.id}',
        data: profile.toRequestJson(),
      ),
    );
  }

  /// DELETE /api/profiles/:id
  Future<void> deleteProfile(int profileId) async {
    try {
      await _apiClient.dio.delete<void>('/profiles/$profileId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ChildProfile> _writeProfile(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      final profile = response.data?['profile'] as Map<String, dynamic>?;
      if (profile == null) {
        throw const ApiException(message: '서버 응답이 비어 있어요.');
      }
      return ChildProfile.fromJson(profile);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
