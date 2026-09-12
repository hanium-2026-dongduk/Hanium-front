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
  bool _isRefreshing = false;
  String? _errorMessage;

  int get points => _points;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  Future<void> refresh(int childProfileId) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    try {
      _points = await _rewardService.fetchPointBalance(childProfileId);
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
