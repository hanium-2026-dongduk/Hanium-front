import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 백엔드는 모든 응답을 `{ success, message, data }` 봉투에 담아 내려준다.
/// (docs/API_SPEC_AUTH.md 공통 응답 포맷)
///
/// 실제 값은 전부 `data` 안에 있으므로, 서비스 계층은 이 헬퍼로 봉투를 벗겨서 쓴다.
/// 실패 응답은 `data`가 없고 `message`만 있으므로 그건 [ApiException]이 처리한다.
class ApiResponse {
  ApiResponse._();

  /// 성공 응답의 `data`를 꺼낸다.
  ///
  /// 로그아웃처럼 `data`가 아예 없는 성공 응답도 있어서, 없으면 빈 맵을 준다.
  static Map<String, dynamic> data(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map) {
      throw const ApiException(message: '서버 응답 형식이 올바르지 않아요.');
    }

    final data = body['data'];
    if (data == null) return const {};
    if (data is! Map) {
      throw const ApiException(message: '서버 응답 형식이 올바르지 않아요.');
    }
    return Map<String, dynamic>.from(data);
  }

  /// `data` 안에서 다시 한 단계 들어가야 하는 응답용. (예: `data.profile`)
  static Map<String, dynamic> nested(Response<dynamic> response, String key) {
    final inner = data(response)[key];
    if (inner is! Map) {
      throw const ApiException(message: '서버 응답이 비어 있어요.');
    }
    return Map<String, dynamic>.from(inner);
  }

  /// `data` 안의 리스트용. (예: `data.profiles`)
  static List<Map<String, dynamic>> list(Response<dynamic> response, String key) {
    final inner = data(response)[key];
    if (inner is! List) return const [];
    return inner.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}
