import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// 액세스/리프레시 토큰과 로그인한 보호자 정보를 기기 보안 저장소에 보관한다.
/// SharedPreferences와 달리 안드로이드 Keystore / iOS Keychain으로 암호화된다.
///
/// 백엔드에 `GET /users/me` 같은 "내 정보" 엔드포인트가 없어서, 로그인할 때 받은
/// user를 여기 같이 저장해두고 앱 재시작 시 복원한다.
class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveUser(User user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  /// 저장된 값이 깨졌더라도 앱이 못 뜨는 일은 없어야 하므로 null로 떨어뜨린다.
  Future<User?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 로그아웃하거나 토큰 갱신이 실패했을 때 전부 지운다.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
