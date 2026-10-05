import '../core/api_client.dart';

class UsageService {
  final ApiClient _apiClient;

  UsageService(this._apiClient);

  Future<Map<String, dynamic>> getTodayUsage(int childId) async {
    final response = await _apiClient.dio.get('/usage/$childId/today');
    return response.data['data'];
  }
}
