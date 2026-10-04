import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/dashboard_summary.dart';
import '../services/dashboard_service.dart';

/// 메인 화면의 동화·단어·퀴즈 집계. 현재 자녀가 바뀌면 이전 자녀의 결과를 버린다.
class MainDashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  MainDashboardProvider({required DashboardService service})
    : _service = service;

  DashboardSummary? _summary;
  int? _childProfileId;
  bool _isLoading = false;
  String? _errorMessage;
  int _requestVersion = 0;
  bool _disposed = false;

  DashboardSummary? get summary => _summary;
  int? get childProfileId => _childProfileId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load(int? childProfileId) async {
    if (_disposed) return;
    if (childProfileId == null) {
      _requestVersion++;
      _childProfileId = null;
      _summary = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (_isLoading && _childProfileId == childProfileId) return;

    final version = ++_requestVersion;
    if (_childProfileId != childProfileId) _summary = null;
    _childProfileId = childProfileId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.fetchSummary(childProfileId);
      if (_disposed || version != _requestVersion) return;
      _summary = result;
    } on ApiException catch (error) {
      if (_disposed || version != _requestVersion) return;
      _errorMessage = error.message;
    } finally {
      if (!_disposed && version == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
