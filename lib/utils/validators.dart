/// 인증 화면들이 공유하는 입력값 검증 규칙.
/// 서버 검증과 어긋나지 않도록 규칙을 바꿀 때는 백엔드와 같이 맞춘다.
class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return '이메일을 입력해 주세요.';
    if (!_emailPattern.hasMatch(input)) return '이메일 형식이 올바르지 않아요.';
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return '비밀번호를 입력해 주세요.';
    if (input.length < 8) return '비밀번호는 8자 이상이어야 해요.';
    return null;
  }

  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return '이름을 입력해 주세요.';
    if (input.length > 20) return '이름은 20자까지 쓸 수 있어요.';
    return null;
  }

  /// 로그인 화면에서는 길이 규칙까지 볼 필요가 없어서 빈 값만 확인한다.
  static String? required(String? value, String label) {
    if ((value?.trim() ?? '').isEmpty) return '$label을(를) 입력해 주세요.';
    return null;
  }
}
