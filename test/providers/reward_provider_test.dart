import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/reward_detail.dart';
import 'package:hanium_front/providers/reward_provider.dart';
import 'package:hanium_front/services/reward_service.dart';

class _FakeRewardService implements RewardService {
  RewardDetail? next;
  ApiException? error;

  @override
  Future<RewardDetail> fetchDetail(int childProfileId) async {
    if (error != null) throw error!;
    return next!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RewardDetail _detail({required int points, required int level, int childId = 1}) =>
    RewardDetail(childProfileId: childId, points: points, level: level, streakDays: 0);

/// 포인트·레벨 공유 상태(MN02, RW04)와 레벨업 감지(RW05)를 본다.
void main() {
  late _FakeRewardService service;
  late RewardProvider provider;

  setUp(() {
    service = _FakeRewardService();
    provider = RewardProvider(rewardService: service);
  });

  test('불러오면 포인트와 레벨을 저장한다', () async {
    service.next = _detail(points: 340, level: 3);

    await provider.refresh(1);

    expect(provider.points, 340);
    expect(provider.level, 3);
    expect(provider.takeLevelUp(), isNull);
  });

  test('처음 불러올 때는 레벨업으로 보지 않는다', () async {
    service.next = _detail(points: 1000, level: 5);

    await provider.refresh(1);

    expect(provider.takeLevelUp(), isNull);
  });

  test('레벨이 오르면 새 레벨을 한 번만 알려준다', () async {
    service.next = _detail(points: 290, level: 2);
    await provider.refresh(1);

    service.next = _detail(points: 310, level: 3);
    await provider.refresh(1);

    expect(provider.takeLevelUp(), 3);
    expect(provider.takeLevelUp(), isNull);
  });

  test('레벨이 그대로면 레벨업이 아니다', () async {
    service.next = _detail(points: 310, level: 3);
    await provider.refresh(1);

    service.next = _detail(points: 350, level: 3);
    await provider.refresh(1);

    expect(provider.takeLevelUp(), isNull);
  });

  test('다른 자녀로 바뀐 직후에는 레벨업으로 보지 않는다', () async {
    service.next = _detail(points: 100, level: 2);
    await provider.refresh(1);

    service.next = _detail(points: 3000, level: 8, childId: 2);
    await provider.refresh(2);

    expect(provider.takeLevelUp(), isNull);
    expect(provider.level, 8);
  });

  test('실패하면 오류 메시지를 담고 이전 값을 유지한다', () async {
    service.next = _detail(points: 340, level: 3);
    await provider.refresh(1);

    service.error = const ApiException(message: '서버에 연결할 수 없어요.');
    await provider.refresh(1);

    expect(provider.errorMessage, '서버에 연결할 수 없어요.');
    expect(provider.points, 340);
    expect(provider.level, 3);
  });
}
