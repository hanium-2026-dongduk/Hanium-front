import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/dashboard_summary.dart';
import 'package:hanium_front/providers/main_dashboard_provider.dart';
import 'package:hanium_front/services/dashboard_service.dart';

class _FakeDashboardService implements DashboardService {
  final Map<int, Completer<DashboardSummary>> requests = {};

  @override
  Future<DashboardSummary> fetchSummary(int childProfileId) {
    final request = Completer<DashboardSummary>();
    requests[childProfileId] = request;
    return request.future;
  }
}

const _first = DashboardSummary(
  storyCount: 2,
  favoriteStoryCount: 1,
  vocabularyCount: 4,
  quizStats: QuizStats(totalAttempts: 1),
);
const _second = DashboardSummary(
  storyCount: 7,
  favoriteStoryCount: 3,
  vocabularyCount: 9,
  quizStats: QuizStats(totalAttempts: 5),
);

void main() {
  test('자녀가 바뀌면 이전 자녀의 늦은 응답을 화면에 반영하지 않는다', () async {
    final service = _FakeDashboardService();
    final provider = MainDashboardProvider(service: service);

    final firstLoad = provider.load(1);
    final secondLoad = provider.load(2);
    expect(provider.summary, isNull);
    expect(provider.childProfileId, 2);

    service.requests[2]!.complete(_second);
    await secondLoad;
    service.requests[1]!.complete(_first);
    await firstLoad;

    expect(provider.summary?.storyCount, 7);
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  test('API 오류를 표시하고 재시도하면 다시 집계를 불러온다', () async {
    final service = _FakeDashboardService();
    final provider = MainDashboardProvider(service: service);

    final failed = provider.load(3);
    service.requests[3]!.completeError(const ApiException(message: '네트워크 오류'));
    await failed;
    expect(provider.errorMessage, '네트워크 오류');

    final retried = provider.load(3);
    service.requests[3]!.complete(_first);
    await retried;
    expect(provider.summary?.vocabularyCount, 4);
    expect(provider.errorMessage, isNull);
    provider.dispose();
  });
}
