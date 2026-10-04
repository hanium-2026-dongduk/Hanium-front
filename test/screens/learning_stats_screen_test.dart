import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/attendance_month.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/dashboard_summary.dart';
import 'package:hanium_front/models/usage_summary.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/learning_stats_provider.dart';
import 'package:hanium_front/screens/mypage/learning_stats_screen.dart';
import 'package:hanium_front/services/attendance_service.dart';
import 'package:hanium_front/services/dashboard_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/usage_service.dart';
import 'package:provider/provider.dart';

class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttendanceService implements AttendanceService {
  ApiException? error;
  Completer<AttendanceMonth>? gate;
  AttendanceMonth month = const AttendanceMonth(
    childProfileId: 1,
    month: '2026-09',
    attendedDates: ['2026-09-01', '2026-09-02', '2026-09-03'],
    attendedCount: 3,
    denominator: 12,
    attendanceRate: 25,
    currentStreak: 3,
  );

  @override
  Future<AttendanceMonth> fetchMonthly(
    int childProfileId, {
    String? month,
  }) async {
    if (error != null) throw error!;
    return gate != null ? gate!.future : this.month;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDashboardService implements DashboardService {
  DashboardSummary summary = const DashboardSummary(
    storyCount: 4,
    favoriteStoryCount: 1,
    readStoryCount: 6,
    vocabularyCount: 9,
    quizStats: QuizStats(totalAttempts: 5, averageScore: 82.5),
  );

  @override
  Future<DashboardSummary> fetchSummary(int childProfileId) async => summary;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUsageService implements UsageService {
  UsageSummary usage = const UsageSummary(
    from: '2026-09-28',
    to: '2026-10-04',
    totalAccumulatedSeconds: 5400,
  );

  @override
  Future<UsageSummary> fetchSummary(
    int childProfileId, {
    String? from,
    String? to,
  }) async => usage;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeAttendanceService attendanceService,
  required _FakeDashboardService dashboardService,
  _FakeUsageService? usageService,
  bool withChild = true,
  bool settle = true,
}) async {
  final activeChild = ActiveChildProvider(
    profileService: const _StubProfileService(),
  );
  if (withChild) {
    activeChild.setActiveChild(
      const ChildProfile(childProfileId: 1, childName: '첫째'),
    );
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<LearningStatsProvider>(
          create: (_) => LearningStatsProvider(
            attendanceService: attendanceService,
            dashboardService: dashboardService,
            usageService: usageService ?? _FakeUsageService(),
          ),
        ),
      ],
      child: const MaterialApp(home: LearningStatsScreen()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('이번 달 출석과 퀴즈 통계를 보여준다', (tester) async {
    await _pumpScreen(
      tester,
      attendanceService: _FakeAttendanceService(),
      dashboardService: _FakeDashboardService(),
    );

    expect(find.text('3일'), findsNWidgets(2)); // 출석 일수, 연속 출석
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('5번'), findsOneWidget);
    expect(find.text('82.5점'), findsOneWidget);
  });

  testWidgets('읽은 동화 수와 최근 7일 학습 시간을 보여준다', (tester) async {
    await _pumpScreen(
      tester,
      attendanceService: _FakeAttendanceService(),
      dashboardService: _FakeDashboardService(),
    );

    expect(find.text('6권'), findsOneWidget);
    expect(find.text('읽은 동화'), findsOneWidget);
    expect(find.text('1시간 30분'), findsOneWidget);
    expect(find.text('최근 7일 학습'), findsOneWidget);
    expect(find.text('곧 만나요'), findsNothing);
  });

  for (final (seconds, label) in [(59, '0분'), (1500, '25분'), (7200, '2시간')]) {
    testWidgets('학습 시간 $seconds초는 분 단위로 내림해 $label으로 보여준다', (tester) async {
      final usageService = _FakeUsageService()
        ..usage = UsageSummary(
          from: '2026-09-28',
          to: '2026-10-04',
          totalAccumulatedSeconds: seconds,
        );
      await _pumpScreen(
        tester,
        attendanceService: _FakeAttendanceService(),
        dashboardService: _FakeDashboardService(),
        usageService: usageService,
      );

      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets('퀴즈를 안 풀었으면 안내 문구를 보여준다', (tester) async {
    final dashboardService = _FakeDashboardService()
      ..summary = const DashboardSummary(
        storyCount: 0,
        favoriteStoryCount: 0,
        vocabularyCount: 0,
        quizStats: QuizStats(totalAttempts: 0),
      );
    await _pumpScreen(
      tester,
      attendanceService: _FakeAttendanceService(),
      dashboardService: dashboardService,
    );

    expect(find.text('아직 푼 퀴즈가 없어요.'), findsOneWidget);
    expect(find.text('평균 점수'), findsNothing);
  });

  testWidgets('출석·독서·학습 시간·퀴즈 기록이 모두 없으면 빈 화면 안내를 보여준다', (tester) async {
    final attendanceService = _FakeAttendanceService()
      ..month = const AttendanceMonth(
        childProfileId: 1,
        month: '2026-09',
        attendedDates: [],
        attendedCount: 0,
        denominator: 12,
        attendanceRate: 0,
        currentStreak: 0,
      );
    final dashboardService = _FakeDashboardService()
      ..summary = const DashboardSummary(
        storyCount: 0,
        favoriteStoryCount: 0,
        vocabularyCount: 0,
        quizStats: QuizStats(totalAttempts: 0),
      );
    final usageService = _FakeUsageService()
      ..usage = const UsageSummary(
        from: '2026-09-28',
        to: '2026-10-04',
        totalAccumulatedSeconds: 0,
      );
    await _pumpScreen(
      tester,
      attendanceService: attendanceService,
      dashboardService: dashboardService,
      usageService: usageService,
    );

    expect(find.textContaining('아직 학습 기록이 없어요'), findsOneWidget);
  });

  testWidgets('출석·퀴즈가 없어도 읽은 동화가 있으면 통계를 보여준다', (tester) async {
    final attendanceService = _FakeAttendanceService()
      ..month = const AttendanceMonth(
        childProfileId: 1,
        month: '2026-09',
        attendedDates: [],
        attendedCount: 0,
        denominator: 12,
        attendanceRate: 0,
        currentStreak: 0,
      );
    final dashboardService = _FakeDashboardService()
      ..summary = const DashboardSummary(
        storyCount: 2,
        favoriteStoryCount: 0,
        readStoryCount: 2,
        vocabularyCount: 0,
        quizStats: QuizStats(totalAttempts: 0),
      );
    await _pumpScreen(
      tester,
      attendanceService: attendanceService,
      dashboardService: dashboardService,
    );

    expect(find.textContaining('아직 학습 기록이 없어요'), findsNothing);
    expect(find.text('2권'), findsOneWidget);
  });

  testWidgets('불러오는 동안 로딩 표시를 보여준다', (tester) async {
    final attendanceService = _FakeAttendanceService()
      ..gate = Completer<AttendanceMonth>();
    await _pumpScreen(
      tester,
      attendanceService: attendanceService,
      dashboardService: _FakeDashboardService(),
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    attendanceService.gate!.complete(attendanceService.month);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final attendanceService = _FakeAttendanceService()
      ..error = const ApiException(message: '서버에 연결할 수 없어요.');
    await _pumpScreen(
      tester,
      attendanceService: attendanceService,
      dashboardService: _FakeDashboardService(),
    );

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('다시 시도를 누르면 다시 불러와 통계를 보여준다', (tester) async {
    final attendanceService = _FakeAttendanceService()
      ..error = const ApiException(message: '서버에 연결할 수 없어요.');
    await _pumpScreen(
      tester,
      attendanceService: attendanceService,
      dashboardService: _FakeDashboardService(),
    );

    attendanceService.error = null;
    await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('이번 달 출석'), findsOneWidget);
  });

  testWidgets('자녀가 선택되지 않았으면 안내 문구를 보여준다', (tester) async {
    await _pumpScreen(
      tester,
      attendanceService: _FakeAttendanceService(),
      dashboardService: _FakeDashboardService(),
      withChild: false,
    );

    expect(find.text('먼저 자녀 프로필을 선택해 주세요.'), findsOneWidget);
  });
}
