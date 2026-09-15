import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/models/reward_history_entry.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/screens/reward_history_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/reward_service.dart';
import 'package:provider/provider.dart';

/// 보상 내역 화면(RW03)이 이력을 사유별로 보여주는지 본다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardService implements RewardService {
  _FakeRewardService(this._items);

  final List<RewardHistoryEntry> _items;
  ApiException? historyError;
  final List<String?> requestedReasons = [];

  @override
  Future<PageResult<RewardHistoryEntry>> fetchHistory(
    int childProfileId, {
    int page = 1,
    int limit = 20,
    String? reason,
  }) async {
    requestedReasons.add(reason);
    if (historyError != null) throw historyError!;
    final filtered = reason == null ? _items : _items.where((e) => e.reason?.wireValue == reason).toList();
    return PageResult(items: filtered, page: 1, limit: limit, totalCount: filtered.length, totalPages: 1);
  }

  @override
  Future<int> fetchPointBalance(int childProfileId) => throw UnimplementedError();

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) => throw UnimplementedError();
}

RewardHistoryEntry _entry({required int points, required RewardReason reason, required int balanceAfter}) {
  return RewardHistoryEntry(
    points: points,
    reason: reason,
    balanceAfter: balanceAfter,
    createdAt: DateTime(2026, 8, 12, 10, 30),
  );
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, _FakeRewardService service) async {
    final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
      ..setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          Provider<RewardService>.value(value: service),
        ],
        child: const MaterialApp(home: RewardHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('이력이 없으면 안내 문구를 보여준다', (tester) async {
    await pumpScreen(tester, _FakeRewardService([]));

    expect(find.text('아직 받은 보상이 없어요.'), findsOneWidget);
  });

  testWidgets('사유·획득량·잔액을 함께 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeRewardService([
        _entry(points: 20, reason: RewardReason.missionReward, balanceAfter: 340),
      ]),
    );

    expect(find.text('미션 완료'), findsOneWidget);
    expect(find.text('+20 토큰'), findsOneWidget);
    expect(find.text('잔액 340'), findsOneWidget);
  });

  testWidgets('사유 필터칩을 누르면 해당 reason으로 다시 조회한다', (tester) async {
    final service = _FakeRewardService([
      _entry(points: 20, reason: RewardReason.missionReward, balanceAfter: 340),
      _entry(points: 30, reason: RewardReason.attendance, balanceAfter: 310),
    ]);
    await pumpScreen(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, '출석'));
    await tester.pumpAndSettle();

    expect(service.requestedReasons.last, 'attendance');
    expect(find.text('오늘 출석'), findsOneWidget);
    expect(find.text('미션 완료'), findsNothing);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final service = _FakeRewardService([])..historyError = const ApiException(message: '서버에 연결할 수 없어요.');
    await pumpScreen(tester, service);

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });
}
