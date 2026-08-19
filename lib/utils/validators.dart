/// 인증 화면들이 공유하는 입력값 검증 규칙.
///
/// 서버 검증과 어긋나면 사용자가 제출한 뒤에야 에러를 보게 되므로,
/// 규칙은 Hanium-back `docs/API_SPEC_AUTH.md` / `API_SPEC_PROFILE.md`에 맞춰둔다.
class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final _letterPattern = RegExp(r'[A-Za-z]');
  static final _digitPattern = RegExp(r'[0-9]');

  /// 영문/숫자/공백이 아닌 문자를 특수문자로 본다. (서버 passwordPolicy와 같은 기준)
  static final _specialPattern = RegExp(r'[^A-Za-z0-9\s]');

  static final _digitsOnlyPattern = RegExp(r'^\d+$');

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return '이메일을 입력해 주세요.';
    if (!_emailPattern.hasMatch(input)) return '이메일 형식이 올바르지 않아요.';
    return null;
  }

  /// 서버 정책(SC01_PWD_01): 8자 이상 + 영문 + 숫자 + 특수문자.
  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return '비밀번호를 입력해 주세요.';
    if (input.length < 8) return '비밀번호는 8자 이상이어야 해요.';
    if (!_letterPattern.hasMatch(input)) return '영문을 1자 이상 넣어 주세요.';
    if (!_digitPattern.hasMatch(input)) return '숫자를 1자 이상 넣어 주세요.';
    if (!_specialPattern.hasMatch(input)) return '특수문자를 1자 이상 넣어 주세요.';
    return null;
  }

  /// 이메일로 받는 6자리 숫자 인증번호. 유효시간 5분.
  static String? verificationCode(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return '인증번호를 입력해 주세요.';
    if (input.length != 6 || !_digitsOnlyPattern.hasMatch(input)) {
      return '인증번호는 숫자 6자리예요.';
    }
    return null;
  }

  /// 자녀 이름. 서버 `child_name`은 1~100자다.
  static String? childName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return '이름을 입력해 주세요.';
    if (input.length > 100) return '이름은 100자까지 쓸 수 있어요.';
    return null;
  }

  /// 자녀 나이. 선택 항목이라 비워둘 수 있고, 넣는다면 서버 범위(1~15)를 지켜야 한다.
  static String? childAge(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;

    final age = int.tryParse(input);
    if (age == null) return '나이는 숫자로 입력해 주세요.';
    if (age < 1 || age > 15) return '나이는 1살부터 15살까지 넣을 수 있어요.';
    return null;
  }

  /// 로그인 화면에서는 길이 규칙까지 볼 필요가 없어서 빈 값만 확인한다.
  static String? required(String? value, String label) {
    if ((value?.trim() ?? '').isEmpty) {
      return '$label${objectParticle(label)} 입력해 주세요.';
    }
    return null;
  }

  /// 앞 글자의 받침 유무에 맞는 목적격 조사를 고른다. ('이메일을', '비밀번호를')
  ///
  /// 한글 음절은 유니코드에서 (가 + 초성*588 + 중성*28 + 종성) 순으로 배열돼 있어,
  /// 28로 나눈 나머지가 0이 아니면 받침이 있다.
  static String objectParticle(String word) {
    if (word.isEmpty) return '을';

    final code = word.codeUnitAt(word.length - 1);
    // 한글 음절 영역이 아니면(영문·숫자 등) 판단할 수 없으니 무난한 쪽으로 둔다.
    if (code < 0xAC00 || code > 0xD7A3) return '을';

    return (code - 0xAC00) % 28 == 0 ? '를' : '을';
  }
}
