import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/attendance_month.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/daily_mission.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/models/reward_history_entry.dart';
import 'package:hanium_front/models/user.dart';
import 'package:hanium_front/models/vocabulary_entry.dart';

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

  group('VocabularyEntry 직렬화는', () {
    test('서버가 주는 모든 필드를 읽는다', () {
      final entry = VocabularyEntry.fromJson({
        'vocabulary_entry_id': 10,
        'child_profile_id': 3,
        'story_id': 5,
        'english_word': 'castle',
        'korean_meaning': '성, 대저택',
        'example_sentence': 'The castle is big.',
        'is_favorite': false,
        'created_at': '2026-08-12T01:23:45.000Z',
      });

      expect(entry.vocabularyEntryId, 10);
      expect(entry.childProfileId, 3);
      expect(entry.storyId, 5);
      expect(entry.englishWord, 'castle');
      expect(entry.koreanMeaning, '성, 대저택');
      expect(entry.exampleSentence, 'The castle is big.');
      expect(entry.isFavorite, isFalse);
    });

    test('BIGINT id가 문자열로 와도 정수로 읽는다', () {
      final entry = VocabularyEntry.fromJson({
        'vocabulary_entry_id': '9007199254740993',
        'child_profile_id': '3',
        'created_at': '2026-08-12T01:23:45.000Z',
      });

      expect(entry.vocabularyEntryId, isA<int>());
      expect(entry.childProfileId, 3);
    });

    test('story_id와 example_sentence가 없어도 안전하게 읽는다', () {
      final entry = VocabularyEntry.fromJson({
        'vocabulary_entry_id': 1,
        'child_profile_id': 1,
        'english_word': 'magic',
        'korean_meaning': '마법',
        'created_at': '2026-08-12T01:23:45.000Z',
      });

      expect(entry.storyId, isNull);
      expect(entry.exampleSentence, isNull);
    });

    test('copyWith으로 즐겨찾기 상태만 바꿀 수 있다', () {
      final entry = VocabularyEntry.fromJson({
        'vocabulary_entry_id': 1,
        'child_profile_id': 1,
        'english_word': 'magic',
        'korean_meaning': '마법',
        'created_at': '2026-08-12T01:23:45.000Z',
      });

      final favorited = entry.copyWith(isFavorite: true);
      expect(favorited.isFavorite, isTrue);
      expect(favorited.englishWord, entry.englishWord);
      expect(entry.isFavorite, isFalse); // 원본은 그대로다.
    });
  });

  group('DailyMission 직렬화는', () {
    test('진행 상황 응답의 필드를 읽는다', () {
      final mission = DailyMission.fromJson({
        'missionType': 'word_clicked',
        'targetCount': 5,
        'progressCount': 2,
        'rewardPoints': 15,
        'status': 'pending',
      });

      expect(mission.type, MissionType.wordClicked);
      expect(mission.targetCount, 5);
      expect(mission.progressCount, 2);
      expect(mission.rewardPoints, 15);
      expect(mission.status, MissionStatus.pending);
      expect(mission.progress, closeTo(0.4, 0.001));
    });

    test('카탈로그 응답처럼 progressCount/status가 없으면 안전한 기본값으로 읽는다', () {
      final mission = DailyMission.fromJson({
        'missionType': 'attendance',
        'targetCount': 1,
        'rewardPoints': 10,
      });

      expect(mission.progressCount, 0);
      expect(mission.status, MissionStatus.pending);
    });

    test('completed와 rewarded는 둘 다 완료로 취급한다', () {
      expect(MissionStatus.fromWire('completed').isDone, isTrue);
      expect(MissionStatus.fromWire('rewarded').isDone, isTrue);
      expect(MissionStatus.fromWire('pending').isDone, isFalse);
    });

    test('모르는 missionType은 attendance로 떨어뜨린다', () {
      expect(MissionType.fromWire('unknown_type'), MissionType.attendance);
    });
  });

  group('AttendanceCheckResult / AttendanceMonth 직렬화는', () {
    test('출석 체크 응답을 읽는다', () {
      final result = AttendanceCheckResult.fromJson({
        'attendanceDate': '2026-08-12',
        'alreadyChecked': false,
        'streakDays': 3,
        'pointsEarned': 30,
        'badgesAwarded': ['3일 연속 출석'],
      });

      expect(result.alreadyChecked, isFalse);
      expect(result.streakDays, 3);
      expect(result.pointsEarned, 30);
      expect(result.badgesAwarded, ['3일 연속 출석']);
    });

    test('badgesAwarded가 없으면 빈 목록으로 읽는다', () {
      final result = AttendanceCheckResult.fromJson({
        'attendanceDate': '2026-08-12',
        'alreadyChecked': true,
        'streakDays': 3,
        'pointsEarned': 0,
      });

      expect(result.badgesAwarded, isEmpty);
    });

    test('월간 출석 현황 응답을 읽는다', () {
      final month = AttendanceMonth.fromJson({
        'childProfileId': 1,
        'month': '2026-08',
        'attendedDates': ['2026-08-01', '2026-08-03'],
        'attendedCount': 2,
        'denominator': 12,
        'attendanceRate': 16.7,
        'currentStreak': 1,
      });

      expect(month.attendedDates, ['2026-08-01', '2026-08-03']);
      expect(month.attendedCount, 2);
      expect(month.attendanceRate, 16.7);
      expect(month.currentStreak, 1);
    });

    test('연속 출석 마일스톤은 다음 목표를 정확히 찾는다', () {
      expect(StreakMilestones.nextMilestone(0), 3);
      expect(StreakMilestones.nextMilestone(3), 7);
      expect(StreakMilestones.nextMilestone(29), 30);
      expect(StreakMilestones.nextMilestone(30), isNull);
    });
  });

  group('RewardHistoryEntry / RewardDetail 직렬화는', () {
    test('이력 한 건을 읽고 로컬 시각으로 바꾼다', () {
      final entry = RewardHistoryEntry.fromJson({
        'points': 20,
        'reason': 'mission_reward',
        'balanceAfter': 340,
        'createdAt': '2026-08-12T01:23:45.000Z',
        'metadata': {'missionType': 'story_read'},
      });

      expect(entry.points, 20);
      expect(entry.reason, RewardReason.missionReward);
      expect(entry.balanceAfter, 340);
      expect(entry.metadata['missionType'], 'story_read');
    });

    test('모르는 reason은 null로 둔다', () {
      final entry = RewardHistoryEntry.fromJson({
        'points': 5,
        'reason': 'unknown_reason',
        'balanceAfter': 5,
        'createdAt': '2026-08-12T01:23:45.000Z',
      });

      expect(entry.reason, isNull);
    });

    test('레벨 상세 응답을 읽는다', () {
      final detail = RewardDetail.fromJson({
        'childProfileId': 1,
        'points': 340,
        'level': 3,
        'streakDays': 4,
        'levelProgress': {
          'currentLevelFloor': 300,
          'nextLevelAt': 600,
          'pointsToNextLevel': 260,
        },
      });

      expect(detail.points, 340);
      expect(detail.level, 3);
      expect(detail.levelProgress?.nextLevelAt, 600);
    });

    test('최고 레벨에서는 nextLevelAt이 null이어도 안전하게 읽는다', () {
      final detail = RewardDetail.fromJson({
        'childProfileId': 1,
        'points': 6000,
        'level': 10,
        'streakDays': 0,
        'levelProgress': {
          'currentLevelFloor': 5200,
          'nextLevelAt': null,
          'pointsToNextLevel': null,
        },
      });

      expect(detail.levelProgress?.nextLevelAt, isNull);
      expect(detail.levelProgress?.pointsToNextLevel, isNull);
    });
  });

  group('PageResult 직렬화는', () {
    test('items와 pagination을 함께 읽는다', () {
      final result = PageResult.fromJson({
        'items': [
          {'points': 10},
          {'points': 20},
        ],
        'pagination': {'page': 1, 'limit': 20, 'totalCount': 37, 'totalPages': 2},
      }, (json) => json['points'] as int);

      expect(result.items, [10, 20]);
      expect(result.page, 1);
      expect(result.totalPages, 2);
      expect(result.hasMore, isTrue);
    });

    test('마지막 페이지는 hasMore가 false다', () {
      final result = PageResult.fromJson({
        'items': [],
        'pagination': {'page': 2, 'limit': 20, 'totalCount': 37, 'totalPages': 2},
      }, (json) => json['points'] as int);

      expect(result.hasMore, isFalse);
    });
  });
}
