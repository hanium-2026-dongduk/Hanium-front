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
    test('빈 값과 7자는 거부한다', () {
      expect(Validators.password(''), '비밀번호를 입력해 주세요.');
      expect(Validators.password('Aa1!567'), '비밀번호는 8자 이상이어야 해요.');
    });

    test('서버 정책대로 영문·숫자·특수문자를 각각 요구한다', () {
      // 길이는 충분하지만 한 종류씩 빠진 경우
      expect(Validators.password('12345678!'), '영문을 1자 이상 넣어 주세요.');
      expect(Validators.password('abcdefgh!'), '숫자를 1자 이상 넣어 주세요.');
      expect(Validators.password('abcdefg1'), '특수문자를 1자 이상 넣어 주세요.');
    });

    test('세 종류를 모두 갖춘 8자는 통과한다', () {
      expect(Validators.password('abcdefg1!'), isNull);
      expect(Validators.password('Aa1!Aa1!'), isNull);
    });
  });

  group('인증번호 검증은', () {
    test('숫자 6자리만 허용한다', () {
      expect(Validators.verificationCode(''), '인증번호를 입력해 주세요.');
      expect(Validators.verificationCode('12345'), '인증번호는 숫자 6자리예요.');
      expect(Validators.verificationCode('1234567'), '인증번호는 숫자 6자리예요.');
      expect(Validators.verificationCode('12345a'), '인증번호는 숫자 6자리예요.');
      expect(Validators.verificationCode(' 123456 '), isNull);
    });
  });

  group('자녀 이름 검증은', () {
    test('공백은 제거해 검사하고 100자는 허용하지만 101자는 거부한다', () {
      expect(Validators.childName('   '), '이름을 입력해 주세요.');
      expect(Validators.childName('가' * 100), isNull);
      expect(Validators.childName('가' * 101), '이름은 100자까지 쓸 수 있어요.');
    });
  });

  group('자녀 나이 검증은', () {
    test('선택 항목이라 비워두면 통과한다', () {
      expect(Validators.childAge(null), isNull);
      expect(Validators.childAge('  '), isNull);
    });

    test('서버 범위(1~15)를 벗어나거나 숫자가 아니면 거부한다', () {
      expect(Validators.childAge('일곱'), '나이는 숫자로 입력해 주세요.');
      expect(Validators.childAge('0'), '나이는 1살부터 15살까지 넣을 수 있어요.');
      expect(Validators.childAge('16'), '나이는 1살부터 15살까지 넣을 수 있어요.');
      expect(Validators.childAge('1'), isNull);
      expect(Validators.childAge('15'), isNull);
    });
  });

  group('필수값 검증은', () {
    test('공백만 있는 입력을 거부하고 라벨을 메시지에 넣는다', () {
      expect(Validators.required('  ', '닉네임'), '닉네임을 입력해 주세요.');
      expect(Validators.required(' 값 ', '닉네임'), isNull);
    });

    test('받침 유무에 맞는 조사를 붙인다', () {
      // 받침 있음 → 을
      expect(Validators.required('', '이메일'), '이메일을 입력해 주세요.');
      // 받침 없음 → 를
      expect(Validators.required('', '비밀번호'), '비밀번호를 입력해 주세요.');
    });
  });

  group('목적격 조사는', () {
    test('받침이 있으면 을, 없으면 를를 고른다', () {
      expect(Validators.objectParticle('이메일'), '을');
      expect(Validators.objectParticle('이름'), '을');
      expect(Validators.objectParticle('비밀번호'), '를');
      expect(Validators.objectParticle('나이'), '를');
    });

    test('한글이 아니거나 빈 문자열이면 을로 둔다', () {
      expect(Validators.objectParticle(''), '을');
      expect(Validators.objectParticle('email'), '을');
      expect(Validators.objectParticle('123'), '을');
    });
  });
}
