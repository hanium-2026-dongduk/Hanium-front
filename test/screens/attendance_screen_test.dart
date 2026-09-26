import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/attendance_month.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/models/reward_history_entry.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/attendance_provider.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/screens/attendance_screen.dart';
import 'package:hanium_front/services/attendance_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:provider/provider.dart';

/// 출석 화면(RW02)이 이번 주 현황과 도장 찍기를 제대로 다루는지 본다.
/// 서버가 멱등하게 처리하므로("같은 날 몇 번 호출해도 안전"), 화면은
/// alreadyChecked/pointsEarned만 보고 UI를 정하면 된다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardService implements RewardService {
  @override
  Future<int> fetchPointBalance(int childProfileId) async => 0;

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) async =>
      const RewardDetail(childProfileId: 1, points: 0, level: 1, streakDays: 0);

  @override
  Future<PageResult<RewardHistoryEntry>> fetchHistory(
    int childProfileId, {
    int page = 1,
    int limit = 20,
    String? reason,
  }) => throw UnimplementedError();
}

class _FakeAttendanceService implements AttendanceService {
  _FakeAttendanceService(this._month);

  final AttendanceMonth _month;
  ApiException? monthlyError;
  final List<int> checkInCalls = [];
  AttendanceCheckResult checkInResult = const AttendanceCheckResult(
    alreadyChecked: false,
    attendanceDate: '2026-08-12',
    streakDays: 1,
    pointsEarned: 10,
  );

  @override
  Future<AttendanceMonth> fetchMonthly(int childProfileId, {String? month}) async {
    if (monthlyError != null) throw monthlyError!;
    return _month;
  }

  @override
  Future<AttendanceCheckResult> checkIn(int childProfileId) async {
    checkInCalls.add(childProfileId);
    return checkInResult;
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeAttendanceService service, {
    bool withChild = true,
  }) async {
    final activeChild = ActiveChildProvider(profileService: const _StubProfileService());
    if (withChild) {
      activeChild.setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));
    }
    final rewardProvider = RewardProvider(rewardService: _FakeRewardService());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          ChangeNotifierProvider<RewardProvider>.value(value: rewardProvider),
          ChangeNotifierProvider<AttendanceProvider>(
            create: (_) => AttendanceProvider(attendanceService: service),
          ),
        ],
        child: const MaterialApp(home: AttendanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  AttendanceMonth monthWith({List<String> attendedDates = const [], int currentStreak = 0}) {
    return AttendanceMonth(
      childProfileId: 1,
      month: '2026-08',
      attendedDates: attendedDates,
      attendedCount: attendedDates.length,
      denominator: 12,
      attendanceRate: 0,
      currentStreak: currentStreak,
    );
  }

  testWidgets('오늘 출석 전이면 도장 찍기 버튼이 활성화된다', (tester) async {
    await pumpScreen(tester, _FakeAttendanceService(monthWith()));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '오늘의 출석 도장 찍기'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('도장을 찍으면 checkIn을 부르고 축하 연출을 보여준다', (tester) async {
    final service = _FakeAttendanceService(monthWith())
      ..checkInResult = const AttendanceCheckResult(
        alreadyChecked: false,
        attendanceDate: '2026-08-12',
        streakDays: 3,
        pointsEarned: 30,
      );
    await pumpScreen(tester, service);

    await tester.tap(find.widgetWithText(ElevatedButton, '오늘의 출석 도장 찍기'));
    await tester.pumpAndSettle();

    expect(service.checkInCalls, [1]);
    expect(find.textContaining('마법 토큰 30개를 받았어요'), findsOneWidget);
  });

  testWidgets('연속 출석 마일스톤까지 남은 일수를 보여준다', (tester) async {
    await pumpScreen(tester, _FakeAttendanceService(monthWith(currentStreak: 1)));

    expect(find.textContaining('3일 연속 출석까지 2일 남았어요'), findsOneWidget);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final service = _FakeAttendanceService(monthWith())
      ..monthlyError = const ApiException(message: '서버에 연결할 수 없어요.');
    await pumpScreen(tester, service);

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('자녀가 선택되지 않았으면 안내만 보여주고 다시 시도 버튼은 없다', (tester) async {
    await pumpScreen(tester, _FakeAttendanceService(monthWith()), withChild: false);

    expect(find.text('먼저 자녀 프로필을 선택해 주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('자녀를 바꾼 직후 첫 프레임에는 이전 자녀의 출석을 보여주지 않는다', (tester) async {
    final service = _FakeAttendanceService(monthWith(currentStreak: 5));
    final provider = AttendanceProvider(attendanceService: service);
    await provider.load(1); // 첫째 화면을 봤던 상태로 Provider에 값이 남아 있다.

    final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
      ..setActiveChild(const ChildProfile(childProfileId: 2, childName: '둘째'));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          ChangeNotifierProvider<RewardProvider>.value(
            value: RewardProvider(rewardService: _FakeRewardService()),
          ),
          ChangeNotifierProvider<AttendanceProvider>.value(value: provider),
        ],
        child: const MaterialApp(home: AttendanceScreen()),
      ),
    );

    // 첫 프레임: 불러오기가 시작되기 전이므로 이전 자녀의 값 대신 로딩만 보여야 한다.
    expect(find.textContaining('연속 5일'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.textContaining('연속 5일'), findsOneWidget);
  });

  testWidgets('이미 보여 주던 출석은 새로고침이 실패해도 지우지 않고 안내만 띄운다', (tester) async {
    final service = _FakeAttendanceService(monthWith(currentStreak: 2));
    await pumpScreen(tester, service);
    expect(find.textContaining('연속 2일'), findsOneWidget);

    service.monthlyError = const ApiException(message: '서버에 연결할 수 없어요.');
    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.textContaining('연속 2일'), findsOneWidget); // 출석 지도는 그대로
    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget); // 스낵바
    expect(find.text('다시 시도'), findsNothing);
  });
}
