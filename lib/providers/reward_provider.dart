import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../services/reward_service.dart';

/// 보유 포인트("토큰")를 앱 전체가 공유하기 위한 Provider. (P-MN-MN02)
///
/// 메인 화면 상단 표시와 출석/미션 화면이 같은 값을 봐야 하므로, 출석 체크나
/// 미션 완료처럼 포인트가 바뀔 수 있는 동작 뒤에는 항상 [refresh]를 호출한다.
///
/// `auth_provider.dart`의 `_run()` 래퍼와 같은 이유로 [isRefreshing]을 둔다 —
/// 출석 버튼을 연달아 눌러도 요청이 겹치지 않게 막는 용도다.
class RewardProvider extends ChangeNotifier {
  final RewardService _rewardService;

  RewardProvider({required RewardService rewardService}) : _rewardService = rewardService;

  int _points = 0;
  int _level = 0;
  int? _levelChildId;
  int? _pendingLevelUp;
  bool _isRefreshing = false;
  String? _errorMessage;

  int get points => _points;

  /// 현재 레벨. 아직 불러오기 전이면 0이다. (P-GM-RW04)
  int get level => _level;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// 마지막 [refresh]에서 레벨이 올랐다면 새 레벨을 한 번만 돌려주고 비운다. (P-GM-RW05)
  /// 축하 연출을 띄우는 화면이 호출한다.
  int? takeLevelUp() {
    final level = _pendingLevelUp;
    _pendingLevelUp = null;
    return level;
  }

  Future<void> refresh(int childProfileId) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    try {
      final detail = await _rewardService.fetchDetail(childProfileId);
      // 처음 불러올 때나 자녀가 바뀐 직후는 비교 기준이 없으므로 레벨업으로 보지 않는다.
      if (_levelChildId == childProfileId && detail.level > _level) {
        _pendingLevelUp = detail.level;
      }
      _levelChildId = childProfileId;
      _level = detail.level;
      _points = detail.points;
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
