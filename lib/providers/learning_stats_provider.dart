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
  bool _isLoading = false;
  String? _errorMessage;

  AttendanceMonth? get attendance => _attendance;
  DashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load(int childProfileId) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _attendanceService.fetchMonthly(childProfileId),
        _dashboardService.fetchSummary(childProfileId),
      ]);
      _attendance = results[0] as AttendanceMonth;
      _summary = results[1] as DashboardSummary;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
