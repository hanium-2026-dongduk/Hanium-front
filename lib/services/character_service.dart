import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/api_response.dart';
import '../models/character.dart';

/// 동화 속 캐릭터 목록 조회·생성. (P-SG01)
///
/// 계약은 Hanium-back `src/routes/character.router.js` 기준. 이 API는 인증이
/// 없고 자녀·사용자별로 구분되지도 않아(back#40 3번) 목록에 다른 사용자가
/// 만든 캐릭터도 섞여 나올 수 있다.
class CharacterService {
  final ApiClient _apiClient;

  CharacterService(this._apiClient);

  /// GET /api/characters → data: [Character]
  Future<List<Character>> fetchCharacters(int childProfileId) {
    return _call(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/characters',
        queryParameters: {'child_profile_id': childProfileId},
      ),
      (response) =>
          ApiResponse.dataList(response).map(Character.fromJson).toList(),
    );
  }

  /// POST /api/characters { name, personality, description, imageUrl, type } → data: Character
  /// name이 비어 있으면 400.
  Future<Character> createCharacter({
    required int childProfileId, // 필수 파라미터로 추가
    required String name,
    String personality = '밝음',
    String description = '',
    String? imageUrl,
    String type = CharacterType.custom,
  }) {
    return _call(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/characters',
        data: {
          'child_profile_id': childProfileId, // 서버로 전송
          'name': name,
          'personality': personality,
          'description': description,
          if (imageUrl != null) 'imageUrl': imageUrl,
          'type': type,
        },
      ),
      (response) => Character.fromJson(ApiResponse.data(response)),
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
