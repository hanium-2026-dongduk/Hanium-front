import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/attendance_month.dart';
import 'package:hanium_front/providers/attendance_provider.dart';
import 'package:hanium_front/services/attendance_service.dart';

/// 출석 Provider가 자녀별로 값을 분리하고 도장 찍기 결과·실패를 다루는지 본다.
class _FakeAttendanceService implements AttendanceService {
  final Map<int, Completer<AttendanceMonth>> pending = {};
  ApiException? checkInError;
  final List<int> checkInCalls = [];

  @override
  Future<AttendanceMonth> fetchMonthly(int childProfileId, {String? month}) {
    return (pending[childProfileId] = Completer<AttendanceMonth>()).future;
  }

  @override
  Future<AttendanceCheckResult> checkIn(int childProfileId) async {
    checkInCalls.add(childProfileId);
    if (checkInError != null) throw checkInError!;
    return const AttendanceCheckResult(
      alreadyChecked: false,
      attendanceDate: '2026-09-26',
      streakDays: 1,
      pointsEarned: 10,
    );
  }
}

AttendanceMonth _month(int childId, {int streak = 0}) => AttendanceMonth(
  childProfileId: childId,
  month: '2026-09',
  attendedDates: const [],
  attendedCount: 0,
  denominator: 26,
  attendanceRate: 0,
  currentStreak: streak,
);

void main() {
  test('불러오면 이번 달 출석과 자녀 id를 보관한다', () async {
    final service = _FakeAttendanceService();
    final provider = AttendanceProvider(attendanceService: service);

    final loading = provider.load(1);
    expect(provider.isLoading, isTrue);
    service.pending[1]!.complete(_month(1, streak: 4));
    await loading;

    expect(provider.isLoading, isFalse);
    expect(provider.loadedChildId, 1);
    expect(provider.month?.currentStreak, 4);
  });

  test('자녀가 바뀌면 이전 자녀의 출석을 비우고, 늦게 도착한 이전 응답은 버린다', () async {
    final service = _FakeAttendanceService();
    final provider = AttendanceProvider(attendanceService: service);

    final first = provider.load(1);
    final firstCompleter = service.pending[1]!;
    final second = provider.load(2); // 1번 응답이 오기 전에 2번으로 바뀐다.
    expect(provider.month, isNull);
    expect(provider.loadedChildId, 2);

    service.pending[2]!.complete(_month(2, streak: 7));
    await second;
    firstCompleter.complete(_month(1, streak: 4)); // 뒤늦게 도착
    await first;

    expect(provider.loadedChildId, 2);
    expect(provider.month?.childProfileId, 2);
    expect(provider.isLoading, isFalse);
  });

  test('불러오기에 실패하면 오류 메시지를 남긴다', () async {
    final service = _FakeAttendanceService();
    final provider = AttendanceProvider(attendanceService: service);

    final loading = provider.load(1);
    service.pending[1]!.completeError(const ApiException(message: '서버에 연결할 수 없어요.'));
    await loading;

    expect(provider.errorMessage, '서버에 연결할 수 없어요.');
    expect(provider.isLoading, isFalse);
  });

  test('도장을 찍으면 결과를 돌려주고 이번 달 현황을 다시 불러온다', () async {
    final service = _FakeAttendanceService();
    final provider = AttendanceProvider(attendanceService: service);

    final checking = provider.checkIn(1);
    expect(provider.isChecking, isTrue);
    await pumpEventQueue();
    service.pending[1]!.complete(_month(1, streak: 1));
    final result = await checking;

    expect(result?.pointsEarned, 10);
    expect(provider.isChecking, isFalse);
    expect(provider.month?.currentStreak, 1);
    expect(provider.checkInError, isNull);
  });

  test('도장 찍기가 진행 중이면 다시 눌러도 요청을 겹치지 않는다', () async {
    final service = _FakeAttendanceService();
    final provider = AttendanceProvider(attendanceService: service);

    final first = provider.checkIn(1);
    final second = await provider.checkIn(1);
    await pumpEventQueue();
    service.pending[1]!.complete(_month(1));
    await first;

    expect(second, isNull);
    expect(service.checkInCalls, [1]);
  });

  test('도장 찍기에 실패하면 null과 이유를 남기고 다시 시도할 수 있다', () async {
    final service = _FakeAttendanceService()
      ..checkInError = const ApiException(message: '네트워크 오류예요.');
    final provider = AttendanceProvider(attendanceService: service);

    final result = await provider.checkIn(1);

    expect(result, isNull);
    expect(provider.checkInError, '네트워크 오류예요.');
    expect(provider.isChecking, isFalse);
  });
}
