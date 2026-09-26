import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/attendance_month.dart';
import 'package:hanium_front/models/badge_status.dart';
import 'package:hanium_front/models/dashboard_summary.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/received_sticker.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/providers/learning_stats_provider.dart';
import 'package:hanium_front/providers/received_sticker_provider.dart';
import 'package:hanium_front/providers/reward_status_provider.dart';
import 'package:hanium_front/services/attendance_service.dart';
import 'package:hanium_front/services/badge_service.dart';
import 'package:hanium_front/services/dashboard_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:hanium_front/services/sticker_service.dart';

/// 마이페이지 Provider는 앱 전역에서 하나를 공유하므로, 자녀가 바뀌면
/// 이전 자녀의 데이터가 남아 보이지 않아야 한다. (자녀 학습·보상 데이터 분리)
class _FakeRewardService implements RewardService {
  final Map<int, Completer<RewardDetail>> pending = {};

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) {
    return (pending[childProfileId] = Completer<RewardDetail>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBadgeService implements BadgeService {
  @override
  Future<BadgeSummary> fetchChildBadges(int childProfileId) async =>
      const BadgeSummary(badges: [], earnedCount: 0, totalCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttendanceService implements AttendanceService {
  final Map<int, Completer<AttendanceMonth>> pending = {};

  @override
  Future<AttendanceMonth> fetchMonthly(int childProfileId, {String? month}) {
    return (pending[childProfileId] = Completer<AttendanceMonth>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDashboardService implements DashboardService {
  @override
  Future<DashboardSummary> fetchSummary(int childProfileId) async => DashboardSummary(
    storyCount: childProfileId,
    favoriteStoryCount: 0,
    vocabularyCount: 0,
    quizStats: const QuizStats(totalAttempts: 0),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStickerService implements StickerService {
  final Map<int, Completer<PageResult<ReceivedSticker>>> pending = {};

  @override
  Future<PageResult<ReceivedSticker>> fetchReceived(
    int childProfileId, {
    int page = 1,
    int limit = 20,
  }) {
    return (pending[childProfileId] = Completer<PageResult<ReceivedSticker>>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RewardDetail _detail(int childId, int points) =>
    RewardDetail(childProfileId: childId, points: points, level: 1, streakDays: 0);

AttendanceMonth _month(int childId, int attended) => AttendanceMonth(
  childProfileId: childId,
  month: '2026-09',
  attendedDates: const [],
  attendedCount: attended,
  denominator: 26,
  attendanceRate: 0,
  currentStreak: 0,
);

PageResult<ReceivedSticker> _stickers(String name) => PageResult(
  items: [ReceivedSticker(stickerSendId: 1, stickerCode: 'well_done', name: name)],
  page: 1,
  limit: 20,
  totalCount: 1,
  totalPages: 1,
);

void main() {
  group('RewardStatusProvider', () {
    late _FakeRewardService service;
    late RewardStatusProvider provider;

    setUp(() {
      service = _FakeRewardService();
      provider = RewardStatusProvider(rewardService: service, badgeService: _FakeBadgeService());
    });

    test('자녀가 바뀌면 이전 자녀의 값을 비우고 새로 불러온다', () async {
      final first = provider.load(1);
      service.pending[1]!.complete(_detail(1, 340));
      await first;
      expect(provider.detail?.points, 340);

      final second = provider.load(2);
      expect(provider.detail, isNull);
      expect(provider.isLoading, isTrue);

      service.pending[2]!.complete(_detail(2, 50));
      await second;
      expect(provider.detail?.points, 50);
    });

    test('새 자녀를 못 불러와도 이전 자녀의 값은 남지 않는다', () async {
      final first = provider.load(1);
      service.pending[1]!.complete(_detail(1, 340));
      await first;

      final second = provider.load(2);
      service.pending[2]!.completeError(const ApiException(message: '서버에 연결할 수 없어요.'));
      await second;

      expect(provider.detail, isNull);
      expect(provider.errorMessage, '서버에 연결할 수 없어요.');
    });

    test('기다리는 사이 자녀가 바뀌면 늦게 온 이전 자녀의 결과는 버린다', () async {
      final first = provider.load(1);
      final second = provider.load(2);

      service.pending[2]!.complete(_detail(2, 50));
      await second;
      service.pending[1]!.complete(_detail(1, 340));
      await first;

      expect(provider.detail?.childProfileId, 2);
      expect(provider.isLoading, isFalse);
    });
  });

  group('LearningStatsProvider', () {
    test('자녀가 바뀌면 이전 자녀의 통계를 비운다', () async {
      final attendance = _FakeAttendanceService();
      final provider = LearningStatsProvider(
        attendanceService: attendance,
        dashboardService: _FakeDashboardService(),
      );

      final first = provider.load(1);
      await Future<void>.delayed(Duration.zero);
      attendance.pending[1]!.complete(_month(1, 5));
      await first;
      expect(provider.attendance?.attendedCount, 5);
      expect(provider.summary?.storyCount, 1);

      final second = provider.load(2);
      expect(provider.attendance, isNull);
      expect(provider.summary, isNull);

      await Future<void>.delayed(Duration.zero);
      attendance.pending[2]!.complete(_month(2, 9));
      await second;
      expect(provider.attendance?.attendedCount, 9);
      expect(provider.summary?.storyCount, 2);
    });
  });

  group('ReceivedStickerProvider', () {
    late _FakeStickerService service;
    late ReceivedStickerProvider provider;

    setUp(() {
      service = _FakeStickerService();
      provider = ReceivedStickerProvider(stickerService: service);
    });

    test('자녀가 바뀌면 이전 자녀의 스티커 목록을 비운다', () async {
      final first = provider.load(1);
      service.pending[1]!.complete(_stickers('잘했어요'));
      await first;
      expect(provider.stickers.single.name, '잘했어요');

      final second = provider.load(2);
      expect(provider.stickers, isEmpty);

      service.pending[2]!.complete(_stickers('최고예요'));
      await second;
      expect(provider.stickers.single.name, '최고예요');
    });

    test('새 자녀를 못 불러오면 이전 자녀의 목록 대신 오류만 남는다', () async {
      final first = provider.load(1);
      service.pending[1]!.complete(_stickers('잘했어요'));
      await first;

      final second = provider.load(2);
      service.pending[2]!.completeError(const ApiException(message: '서버에 연결할 수 없어요.'));
      await second;

      expect(provider.stickers, isEmpty);
      expect(provider.errorMessage, '서버에 연결할 수 없어요.');
    });
  });
}
