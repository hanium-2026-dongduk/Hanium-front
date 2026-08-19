import 'package:dio/dio.dart';

/// 백엔드 errorHandler가 실패를 항상 `{ "message": "..." }` 형태로 내려주므로,
/// 그 메시지를 화면에 바로 보여줄 수 있도록 감싼 예외.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException({required this.message, this.statusCode});

  /// 토큰이 없거나 만료된 경우. 로그인 화면으로 되돌릴 때 구분용으로 쓴다.
  bool get isUnauthorized => statusCode == 401;

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: '서버에 연결할 수 없어요. 네트워크 상태를 확인해 주세요.',
        );
      case DioExceptionType.cancel:
        return const ApiException(message: '요청이 취소되었어요.');
      default:
        return ApiException(
          statusCode: error.response?.statusCode,
          message: _messageFrom(error.response) ?? '알 수 없는 오류가 발생했어요.',
        );
    }
  }

  /// 서버가 message 없이 HTML이나 빈 응답을 줄 수도 있어서 방어적으로 읽는다.
  static String? _messageFrom(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
