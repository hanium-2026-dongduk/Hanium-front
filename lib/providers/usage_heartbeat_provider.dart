import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/api_exception.dart';
import '../services/usage_service.dart';
import 'active_child_provider.dart';
import 'auth_provider.dart';

/// 학습 시간(P-MY-MP03, 보호자 대시보드) 집계를 위해 앱을 쓰는 동안 heartbeat를 보낸다.
///
/// 로그인 상태이고, 활성 자녀가 있고, 앱이 화면 앞(resumed)에 있을 때만 [interval]마다 보낸다.
/// 시간 계산은 서버가 직전 heartbeat와의 간격으로 하므로(1회 최대 90초), 백엔드 권장
/// 간격(30~60초) 안에서 짧은 쪽을 쓴다. 화면과 무관하게 앱 전역에서 한 번만 만든다.
class UsageHeartbeatProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  static const defaultInterval = Duration(seconds: 30);

  final UsageService _usageService;
  final AuthProvider _authProvider;
  final ActiveChildProvider _activeChildProvider;
  final Duration interval;

  UsageHeartbeatProvider({
    required this._usageService,
    required this._authProvider,
    required this._activeChildProvider,
    AppLifecycleState? lifecycleState,
    this.interval = defaultInterval,
  }) : // 앱 시작 직후에는 아직 상태가 없을 수 있어(null) 화면 앞으로 본다.
       _lifecycleState = lifecycleState ?? AppLifecycleState.resumed {
    _authProvider.addListener(_sync);
    _activeChildProvider.addListener(_sync);
    _sync();
  }

  AppLifecycleState _lifecycleState;
  Timer? _timer;
  int? _runningChildId;
  int? _limitReachedChildId;
  final Set<int> _inFlight = {};
  bool _disposed = false;

  /// 지금 heartbeat를 주기적으로 보내는 중인지.
  bool get isRunning => _timer != null;

  /// 활성 자녀가 보호자가 정한 오늘 사용 한도를 넘었는지(서버 403).
  /// 넘으면 송신을 멈추고, 앱이 다시 화면 앞으로 오면 한 번 더 확인한다.
  bool get isLimitReached =>
      _limitReachedChildId != null &&
      _limitReachedChildId == _activeChildProvider.childProfileId;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) _limitReachedChildId = null;
    _sync();
  }

  int? get _targetChildId {
    if (_authProvider.status != AuthStatus.authenticated) return null;
    if (_lifecycleState != AppLifecycleState.resumed) return null;
    final childId = _activeChildProvider.childProfileId;
    if (childId == null || childId == _limitReachedChildId) return null;
    return childId;
  }

  /// 로그인·활성 자녀·앱 상태가 바뀔 때마다 송신 대상을 다시 맞춘다.
  void _sync() {
    if (_disposed) return;
    final target = _targetChildId;
    if (target == _runningChildId) return;

    final previous = _runningChildId;
    _stop();
    // 백그라운드 전환·자녀 전환 직전까지 쓴 시간을 놓치지 않도록 이전 자녀로 한 번 더 보낸다.
    // 로그아웃이면 토큰이 이미 지워졌으므로 보내지 않는다.
    if (previous != null && _authProvider.status == AuthStatus.authenticated) {
      _send(previous);
    }
    if (target == null) return;

    _runningChildId = target;
    _send(target);
    _timer = Timer.periodic(interval, (_) => _send(target));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _runningChildId = null;
  }

  Future<void> _send(int childId) async {
    // 응답이 늦어 이전 요청이 아직 끝나지 않았으면 이번 차례는 건너뛴다.
    if (!_inFlight.add(childId)) return;
    try {
      await _usageService.sendHeartbeat(childId);
    } on ApiException catch (error) {
      if (error.statusCode == 403) _onLimitReached(childId);
      // 그 밖의 실패는 무시한다. 다음 heartbeat가 빠진 시간을 최대 90초까지 채운다.
    } finally {
      _inFlight.remove(childId);
    }
  }

  void _onLimitReached(int childId) {
    if (_disposed) return;
    if (_runningChildId == childId) _stop();
    _limitReachedChildId = childId;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    _authProvider.removeListener(_sync);
    _activeChildProvider.removeListener(_sync);
    super.dispose();
  }
}
