import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/user.dart';

/// 필드 이름은 백엔드가 내려주는 snake_case 그대로여야 한다.
/// (Hanium-back docs/API_SPEC_AUTH.md, API_SPEC_PROFILE.md)
void main() {
  group('User 직렬화는', () {
    test('서버가 주는 snake_case 필드를 읽는다', () {
      final user = User.fromJson({
        'user_id': 7,
        'email': 'a@b.com',
        'role': 'parent',
        'status': 'active',
        'created_at': '2026-07-23T10:00:00.000Z',
      });

      expect(user.userId, 7);
      expect(user.email, 'a@b.com');
      expect(user.role, 'parent');
      expect(user.status, 'active');
    });

    test('BIGINT id가 문자열로 와도 정수로 읽는다', () {
      expect(User.fromJson({'user_id': '9007199254740993'}).userId, isA<int>());
      expect(User.fromJson({'user_id': '42'}).userId, 42);
      expect(User.fromJson({'user_id': 42.0}).userId, 42);
    });

    test('선택 필드가 없거나 null이면 빈 문자열로 읽는다', () {
      final missing = User.fromJson({'user_id': 1});
      final nullable = User.fromJson({
        'user_id': 2,
        'email': null,
        'role': null,
        'status': null,
      });

      expect([missing.email, missing.role, missing.status], ['', '', '']);
      expect([nullable.email, nullable.role, nullable.status], ['', '', '']);
    });

    test('저장용 JSON은 서버 필드명을 그대로 쓴다', () {
      const user = User(
        userId: 3,
        email: 'a@b.com',
        role: 'parent',
        status: 'active',
      );

      expect(user.toJson(), {
        'user_id': 3,
        'email': 'a@b.com',
        'role': 'parent',
        'status': 'active',
      });
    });
  });

  group('ChildProfile 직렬화는', () {
    test('서버가 주는 모든 필드를 읽는다', () {
      final profile = ChildProfile.fromJson({
        'child_profile_id': 3,
        'user_id': 1,
        'child_name': '아이',
        'age': 7,
        'learning_level': 'intermediate',
        'vocabulary_level': '기초 500',
        'profile_image_url': 'https://example.com/a.png',
        'is_active': true,
      });

      expect(profile.childProfileId, 3);
      expect(profile.childName, '아이');
      expect(profile.age, 7);
      expect(profile.learningLevel, LearningLevel.intermediate);
      expect(profile.vocabularyLevel, '기초 500');
      expect(profile.profileImageUrl, 'https://example.com/a.png');
      expect(profile.isActive, isTrue);
    });

    test('모르는 learning_level은 서버 기본값인 beginner로 떨어뜨린다', () {
      expect(
        ChildProfile.fromJson({'child_profile_id': 1, 'learning_level': '없는값'})
            .learningLevel,
        LearningLevel.beginner,
      );
      expect(
        ChildProfile.fromJson({'child_profile_id': 1}).learningLevel,
        LearningLevel.beginner,
      );
    });

    test('선택 필드가 없거나 null이어도 안전하게 읽는다', () {
      final profile = ChildProfile.fromJson({
        'child_profile_id': 1,
        'child_name': null,
        'age': null,
        'vocabulary_level': null,
        'profile_image_url': null,
        'is_active': null,
      });

      expect(profile.childName, '');
      expect(profile.age, isNull);
      expect(profile.vocabularyLevel, isNull);
      expect(profile.profileImageUrl, isNull);
      expect(profile.isActive, isFalse);
    });

    test('요청 JSON은 서버가 허용하는 필드만 담는다', () {
      const profile = ChildProfile(
        childProfileId: 5,
        childName: '아이',
        age: 7,
        learningLevel: LearningLevel.advanced,
        vocabularyLevel: '기초 500',
        profileImageUrl: 'https://example.com/a.png',
        isActive: true,
      );

      expect(profile.toRequestJson(), {
        'child_name': '아이',
        'age': 7,
        'learning_level': 'advanced',
        'vocabulary_level': '기초 500',
        'profile_image_url': 'https://example.com/a.png',
      });
      // 서버가 무시하거나 조작을 막는 필드는 애초에 보내지 않는다.
      expect(
        profile.toRequestJson().keys,
        isNot(contains(anyOf('child_profile_id', 'user_id', 'is_active'))),
      );
    });

    test('값이 없는 선택 필드는 키 자체를 빼서 400을 피한다', () {
      const profile = ChildProfile(childProfileId: 5, childName: '아이');

      expect(profile.toRequestJson(), {
        'child_name': '아이',
        'learning_level': 'beginner',
      });
    });
  });
}
