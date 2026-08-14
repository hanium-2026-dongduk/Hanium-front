import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/user.dart';

void main() {
  group('User 직렬화는', () {
    test('숫자 id와 문자열 필드를 읽고 같은 JSON으로 되돌린다', () {
      final user = User.fromJson({
        'id': 7.0,
        'email': 'a@b.com',
        'name': '보호자',
      });

      expect(user.id, 7);
      expect(user.email, 'a@b.com');
      expect(user.name, '보호자');
      expect(user.toJson(), {'id': 7, 'email': 'a@b.com', 'name': '보호자'});
    });

    test('email과 name이 누락되거나 null이면 빈 문자열로 읽는다', () {
      final missing = User.fromJson({'id': 1});
      final nullable = User.fromJson({'id': 2, 'email': null, 'name': null});

      expect([missing.email, missing.name], ['', '']);
      expect([nullable.email, nullable.name], ['', '']);
    });
  });

  group('ChildProfile 직렬화는', () {
    test('모든 필드를 읽고 요청 JSON에서 id와 시각을 제외한다', () {
      final profile = ChildProfile.fromJson({
        'id': 3.0,
        'name': '아이',
        'birthDate': '2020-05-06T12:34:56.000Z',
        'avatarKey': 'rabbit',
      });

      expect(profile.id, 3);
      expect(profile.name, '아이');
      expect(profile.birthDate, DateTime.parse('2020-05-06T12:34:56.000Z'));
      expect(profile.avatarKey, 'rabbit');
      expect(profile.toRequestJson(), {
        'name': '아이',
        'birthDate': '2020-05-06',
        'avatarKey': 'rabbit',
      });
    });

    test('선택 필드가 누락되거나 null이고 날짜가 잘못돼도 안전하게 읽는다', () {
      final missing = ChildProfile.fromJson({'id': 1, 'name': null});
      final invalid = ChildProfile.fromJson({
        'id': 2,
        'birthDate': '날짜 아님',
        'avatarKey': null,
      });

      expect(missing.name, '');
      expect(missing.birthDate, isNull);
      expect(missing.avatarKey, isNull);
      expect(invalid.name, '');
      expect(invalid.birthDate, isNull);
      expect(invalid.toRequestJson(), {'name': ''});
    });
  });
}
