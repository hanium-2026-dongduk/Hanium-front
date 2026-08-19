import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API 호출에 필요한 설정값을 모아둔 곳.
class ApiConfig {
  ApiConfig._();

  /// 백엔드가 `app.use('/api', routes)`로 라우터를 붙여둬서 /api까지 포함한다.
  static String get baseUrl {
    // .env를 아직 안 만든 팀원도 앱이 뜨도록, 값이 없으면 로컬 기본값으로 떨어진다.
    final fromEnv =
        dotenv.isInitialized ? dotenv.maybeGet('API_BASE_URL') : null;
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
}
