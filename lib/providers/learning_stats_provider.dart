import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/attendance_month.dart';
import '../models/dashboard_summary.dart';
import '../services/attendance_service.dart';
import '../services/dashboard_service.dart';

/// 학습 통계 화면(MP03)의 이번 달 출석과 대시보드 집계를 한 번에 불러오는 Provider.
class LearningStatsProvider extends ChangeNotifier {
  final AttendanceService _attendanceService;
  final DashboardService _dashboardService;

  LearningStatsProvider({
    required AttendanceService attendanceService,
    required DashboardService dashboardService,
  }) : _attendanceService = attendanceService,
       _dashboardService = dashboardService;

  AttendanceMonth? _attendance;
  DashboardSummary? _summary;
  int? _loadedChildId;
  bool _isLoading = false;
  String? _errorMessage;

  AttendanceMonth? get attendance => _attendance;
  DashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load(int childProfileId) async {
    // 같은 자녀를 이미 불러오는 중이면 겹치지 않게 막는다.
    if (_isLoading && _loadedChildId == childProfileId) return;

    // 앱 전역에서 공유되는 Provider라, 자녀가 바뀌면 이전 자녀의 값이 보이지 않게 비운다.
    if (_loadedChildId != childProfileId) {
      _attendance = null;
      _summary = null;
      _loadedChildId = childProfileId;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _attendanceService.fetchMonthly(childProfileId),
        _dashboardService.fetchSummary(childProfileId),
      ]);
      // 기다리는 사이 다른 자녀로 바뀌었다면 이 결과는 버린다.
      if (_loadedChildId != childProfileId) return;
      _attendance = results[0] as AttendanceMonth;
      _summary = results[1] as DashboardSummary;
    } on ApiException catch (error) {
      if (_loadedChildId == childProfileId) _errorMessage = error.message;
    } finally {
      if (_loadedChildId == childProfileId) _isLoading = false;
      notifyListeners();
    }
  }
}
