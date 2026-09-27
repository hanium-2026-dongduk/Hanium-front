import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API 호출에 필요한 설정값을 모아둔 곳.
class ApiConfig {
  ApiConfig._();

  /// 백엔드가 `app.use('/api', routes)`로 라우터를 붙여둬서 /api까지 포함한다.
  static String get baseUrl {
    // .env를 아직 안 만든 팀원도 앱이 뜨도록, 값이 없으면 로컬 기본값으로 떨어진다.
    final fromEnv = dotenv.isInitialized
        ? dotenv.maybeGet('API_BASE_URL')
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return _localBaseUrl;
  }

  /// 안드로이드 에뮬레이터에서 localhost는 '에뮬레이터 자신'을 가리킨다.
  /// 내 PC에서 돌아가는 백엔드는 10.0.2.2로 접근해야 한다.
  static String get _localBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  /// 이미지·TTS 오디오는 `/api` 없이 서버 루트에서 정적으로 서빙된다
  /// (`/images/...`, `/audio/...`). `baseUrl`에서 `/api`만 떼어 호스트를 만든다.
  static String get mediaBaseUrl =>
      baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  /// 서버가 내려준 상대경로를 실제로 요청 가능한 절대 URL로 만든다.
  /// 이미 절대 URL(`http`로 시작)이면 그대로 둔다.
  static String resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$mediaBaseUrl$normalized';
  }
}
