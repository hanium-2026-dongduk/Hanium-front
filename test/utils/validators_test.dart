import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/utils/validators.dart';

void main() {
  group('이메일 검증은', () {
    test('비어 있거나 단순한 도메인 형식이면 알맞은 오류를 반환한다', () {
      expect(Validators.email(null), '이메일을 입력해 주세요.');
      expect(Validators.email('   '), '이메일을 입력해 주세요.');
      expect(Validators.email('a@b'), '이메일 형식이 올바르지 않아요.');
    });

    test('태그와 여러 단계 도메인이 있는 이메일을 허용한다', () {
      expect(Validators.email(' a+tag@sub.example.co.kr '), isNull);
    });
  });

  group('비밀번호 검증은', () {
    test('빈 값과 7자는 거부하고 8자부터 허용한다', () {
      expect(Validators.password(''), '비밀번호를 입력해 주세요.');
      expect(Validators.password('1234567'), '비밀번호는 8자 이상이어야 해요.');
      expect(Validators.password('12345678'), isNull);
    });
  });

  group('이름 검증은', () {
    test('공백은 제거해 검사하고 20자는 허용하지만 21자는 거부한다', () {
      expect(Validators.name('   '), '이름을 입력해 주세요.');
      expect(Validators.name('가' * 20), isNull);
      expect(Validators.name('가' * 21), '이름은 20자까지 쓸 수 있어요.');
    });
  });

  test('필수값 검증은 공백만 있는 입력을 거부하고 라벨을 메시지에 넣는다', () {
    expect(Validators.required('  ', '닉네임'), '닉네임을(를) 입력해 주세요.');
    expect(Validators.required(' 값 ', '닉네임'), isNull);
  });
}
