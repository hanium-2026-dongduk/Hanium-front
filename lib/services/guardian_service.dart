import 'package:dio/dio.dart';
import '../core/api_client.dart';

class GuardianService {
  final ApiClient _apiClient;

  GuardianService(this._apiClient);

  // 1. 보호자 설정 조회 (PIN 설정 여부 등)
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _apiClient.dio.get('/guardian/settings');
    return response.data['data']['setting'];
  }

  // 2. [최초 설정] 비밀번호 확인 -> reauthToken 반환
  Future<String> verifyPassword(String password) async {
    final response = await _apiClient.dio.post(
      '/guardian/reauth',
      data: {'password': password},
    );
    return response.data['data']['reauthToken'];
  }

  // 3. [최초 설정/변경] PIN 설정
  Future<void> setupPin({
    required String pin,
    String? reauthToken,
    String? guardianToken,
  }) async {
    // API 명세에 따라 X-Reauth-Token 또는 X-Guardian-Token 헤더가 필요함
    final headers = <String, String>{};
    if (reauthToken != null) headers['X-Reauth-Token'] = reauthToken;
    if (guardianToken != null) headers['X-Guardian-Token'] = guardianToken;

    await _apiClient.dio.put(
      '/guardian/pin',
      data: {'pin': pin},
      options: Options(headers: headers),
    );
  }

  // 4. [기존 PIN 있음] PIN 검증 -> guardianToken 반환
  Future<String> verifyPin(String pin) async {
    final response = await _apiClient.dio.post(
      '/guardian/pin/verify',
      data: {'pin': pin},
    );
    return response.data['data']['guardianToken'];
  }

  // 5. 보호자 설정 변경 (사용 시간, 푸시 알림)
  Future<void> updateSettings({
    required int limitMinutes,
    required bool pushEnabled,
    required String guardianToken,
  }) async {
    await _apiClient.dio.put(
      '/guardian/settings',
      data: {
        'daily_usage_limit_minutes': limitMinutes,
        'push_enabled': pushEnabled,
      },
      options: Options(
        headers: {'X-Guardian-Token': guardianToken}, // 보호자 전용 요청 헤더 필수
      ),
    );
  }
}
