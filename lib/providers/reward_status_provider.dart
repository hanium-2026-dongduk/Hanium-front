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
  bool _isLoading = false;
  String? _errorMessage;

  RewardDetail? get detail => _detail;
  BadgeSummary? get badges => _badges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load(int childProfileId) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _rewardService.fetchDetail(childProfileId),
        _badgeService.fetchChildBadges(childProfileId),
      ]);
      _detail = results[0] as RewardDetail;
      _badges = results[1] as BadgeSummary;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
