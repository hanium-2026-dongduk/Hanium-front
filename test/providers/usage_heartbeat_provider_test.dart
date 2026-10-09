import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/auth_provider.dart';
import 'package:hanium_front/providers/usage_heartbeat_provider.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/usage_service.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_auth_provider.dart';

class _MockProfileService extends Mock implements ProfileService {}

class _TestAuthProvider extends FakeAuthProvider {
  _TestAuthProvider() : super(status: AuthStatus.authenticated);

  void setStatus(AuthStatus value) {
    status = value;
    notifyListeners();
  }
}

/// 보낸 heartbeat를 기록하고, 자녀별로 실패·지연을 흉내 낸다.
class _FakeUsageService implements UsageService {
  final List<int> calls = [];
  final Set<int> overLimit = {};
  Completer<void>? pending;

  @override
  Future<void> sendHeartbeat(int childProfileId) async {
    calls.add(childProfileId);
    if (pending != null) await pending!.future;
    if (overLimit.contains(childProfileId)) {
      throw const ApiException(statusCode: 403, message: '오늘의 사용 시간이 초과되었습니다.');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChildProfile _child(int id) =>
    ChildProfile(childProfileId: id, childName: '아이$id', isActive: true);

/// 학습 시간 heartbeat가 앱 사용 중에만, 활성 자녀 기준으로 나가는지 본다.
/// 타이머를 가짜 시간으로 돌리려고 testWidgets 안에서 실행한다.
void main() {
  late _TestAuthProvider auth;
  late ActiveChildProvider activeChild;
  late _FakeUsageService usage;
  UsageHeartbeatProvider? heartbeat;

  setUp(() {
    auth = _TestAuthProvider();
    activeChild = ActiveChildProvider(profileService: _MockProfileService());
    usage = _FakeUsageService();
  });

  // testWidgets는 본문이 끝날 때 남은 타이머를 검사하므로 본문 안에서 정리한다.
  void heartbeatTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        heartbeat?.dispose();
        heartbeat = null;
      }
    });
  }

  UsageHeartbeatProvider create({AppLifecycleState? lifecycleState}) {
    return heartbeat = UsageHeartbeatProvider(
      usageService: usage,
      authProvider: auth,
      activeChildProvider: activeChild,
      lifecycleState: lifecycleState,
    );
  }

  const tick = UsageHeartbeatProvider.defaultInterval;

  heartbeatTest('활성 자녀가 없으면 보내지 않다가, 고르면 바로 한 번 보내고 주기마다 보낸다', (tester) async {
    final provider = create();
    await tester.pump(tick);
    expect(usage.calls, isEmpty);
    expect(provider.isRunning, isFalse);

    activeChild.setActiveChild(_child(7));
    expect(usage.calls, [7]);
    expect(provider.isRunning, isTrue);

    await tester.pump(tick);
    await tester.pump(tick);
    expect(usage.calls, [7, 7, 7]);
  });

  heartbeatTest('앱이 뒤로 가면 마지막으로 한 번 보내고 멈췄다가, 돌아오면 다시 보낸다', (tester) async {
    activeChild.setActiveChild(_child(7));
    final provider = create();
    await tester.pump(tick);
    expect(usage.calls, [7, 7]);

    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(usage.calls, [7, 7, 7]);
    expect(provider.isRunning, isFalse);

    await tester.pump(tick * 3);
    expect(usage.calls, [7, 7, 7]);

    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(usage.calls, [7, 7, 7, 7]);
    expect(provider.isRunning, isTrue);
  });

  heartbeatTest('앱이 뒤에 있는 상태로 시작하면 보내지 않는다', (tester) async {
    activeChild.setActiveChild(_child(7));
    create(lifecycleState: AppLifecycleState.hidden);

    await tester.pump(tick);
    expect(usage.calls, isEmpty);
  });

  heartbeatTest('자녀를 바꾸면 이전 자녀로 마지막 한 번, 새 자녀로 이어서 보낸다', (tester) async {
    activeChild.setActiveChild(_child(7));
    create();
    await tester.pump(tick);

    activeChild.setActiveChild(_child(9));
    expect(usage.calls, [7, 7, 7, 9]);

    await tester.pump(tick);
    expect(usage.calls, [7, 7, 7, 9, 9]);
  });

  heartbeatTest('로그아웃하면 더 보내지 않는다', (tester) async {
    activeChild.setActiveChild(_child(7));
    final provider = create();

    auth.setStatus(AuthStatus.unauthenticated);
    expect(provider.isRunning, isFalse);

    await tester.pump(tick * 2);
    expect(usage.calls, [7]);
  });

  heartbeatTest('한도 초과(403)면 멈추고 알리며, 앱이 다시 앞으로 오면 다시 확인한다', (tester) async {
    usage.overLimit.add(7);
    activeChild.setActiveChild(_child(7));
    final provider = create();
    var notified = 0;
    provider.addListener(() => notified++);

    await tester.pump();
    expect(provider.isLimitReached, isTrue);
    expect(provider.isRunning, isFalse);
    expect(notified, 1);

    await tester.pump(tick * 2);
    expect(usage.calls, [7]);

    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    usage.overLimit.clear();
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(provider.isLimitReached, isFalse);
    expect(provider.isRunning, isTrue);
    expect(usage.calls, [7, 7]);
  });

  heartbeatTest('이전 요청이 끝나지 않았으면 그 차례는 건너뛴다', (tester) async {
    usage.pending = Completer<void>();
    activeChild.setActiveChild(_child(7));
    create();

    await tester.pump(tick);
    expect(usage.calls, [7]);

    usage.pending!.complete();
    usage.pending = null;
    await tester.pump(tick);
    expect(usage.calls, [7, 7]);
  });
}
