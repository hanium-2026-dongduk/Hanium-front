/// 보호자 계정. 백엔드 users 테이블과 1:1로 맞춘다.
class User {
  final int id;
  final String email;
  final String name;

  const User({required this.id, required this.email, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['id'] as num).toInt(),
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}
