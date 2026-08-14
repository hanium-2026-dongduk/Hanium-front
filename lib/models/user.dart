import 'json_parse.dart';

/// 보호자 계정. 백엔드 `users` 테이블과 1:1로 맞춘다.
/// 필드 이름은 서버가 내려주는 snake_case 그대로의 의미를 따른다.
/// (Hanium-back `docs/API_SPEC_AUTH.md` 참고)
///
/// 서버 users에는 이름 컬럼이 없다. 화면에 사람 이름이 필요하면 자녀 프로필의
/// `childName`을 쓰거나 별도로 백엔드에 컬럼 추가를 요청해야 한다.
class User {
  final int userId;
  final String email;

  /// 'parent' 등. 서버가 정하는 값이라 앱에서는 읽기만 한다.
  final String role;

  /// 'active' | 'inactive'. 비활성 계정은 로그인 단계에서 403으로 막힌다.
  final String status;

  const User({
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    userId: parseId(json['user_id']),
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );

  /// 앱이 토큰과 함께 보관해두는 용도. 서버로 보내지는 않는다.
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'role': role,
    'status': status,
  };
}
