import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/badge_status.dart';
import '../models/reward_detail.dart';
import '../services/badge_service.dart';
import '../services/reward_service.dart';

/// 보상 현황 화면(MP02)의 포인트·레벨·배지를 한 번에 불러오는 Provider. (P-GM-RW04)
class RewardStatusProvider extends ChangeNotifier {
  final RewardService _rewardService;
  final BadgeService _badgeService;

  RewardStatusProvider({required RewardService rewardService, required BadgeService badgeService})
    : _rewardService = rewardService,
      _badgeService = badgeService;

  RewardDetail? _detail;
  BadgeSummary? _badges;
  int? _loadedChildId;
  bool _isLoading = false;
  String? _errorMessage;

  RewardDetail? get detail => _detail;
  BadgeSummary? get badges => _badges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load(int childProfileId) async {
    // 같은 자녀를 이미 불러오는 중이면 겹치지 않게 막는다.
    if (_isLoading && _loadedChildId == childProfileId) return;

    // 앱 전역에서 공유되는 Provider라, 자녀가 바뀌면 이전 자녀의 값이 보이지 않게 비운다.
    if (_loadedChildId != childProfileId) {
      _detail = null;
      _badges = null;
      _loadedChildId = childProfileId;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _rewardService.fetchDetail(childProfileId),
        _badgeService.fetchChildBadges(childProfileId),
      ]);
      // 기다리는 사이 다른 자녀로 바뀌었다면 이 결과는 버린다.
      if (_loadedChildId != childProfileId) return;
      _detail = results[0] as RewardDetail;
      _badges = results[1] as BadgeSummary;
    } on ApiException catch (error) {
      if (_loadedChildId == childProfileId) _errorMessage = error.message;
    } finally {
      if (_loadedChildId == childProfileId) _isLoading = false;
      notifyListeners();
    }
  }
}
