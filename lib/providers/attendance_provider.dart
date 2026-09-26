import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/attendance_month.dart';
import '../services/attendance_service.dart';

/// 출석 현황 화면(RW02)의 이번 달 출석과 도장 찍기를 맡는 Provider. (P-GM-RW02)
class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService;

  AttendanceProvider({required this._attendanceService});

  AttendanceMonth? _month;
  int? _loadedChildId;
  int _loadSeq = 0; // 가장 최근에 시작한 조회만 결과를 반영한다.
  bool _isLoading = false;
  bool _isChecking = false;
  String? _errorMessage;
  String? _checkInError;

  AttendanceMonth? get month => _month;

  /// 지금 들고 있는 값이 어느 자녀의 것인지. 화면은 자기 자녀와 다르면 값을 쓰지 않는다.
  int? get loadedChildId => _loadedChildId;
  bool get isLoading => _isLoading;
  bool get isChecking => _isChecking;
  String? get errorMessage => _errorMessage;

  /// 마지막 도장 찍기가 실패한 이유. 성공하면 비워진다.
  String? get checkInError => _checkInError;

  /// [force]가 true면 같은 자녀를 이미 불러오는 중이어도 다시 불러온다.
  /// (도장을 찍은 직후에는 진행 중이던 조회 결과가 도장 이전 값일 수 있다.)
  Future<void> load(int childProfileId, {bool force = false}) async {
    // 같은 자녀를 이미 불러오는 중이면 겹치지 않게 막는다.
    if (!force && _isLoading && _loadedChildId == childProfileId) return;
    final seq = ++_loadSeq;

    // 앱 전역에서 공유되는 Provider라, 자녀가 바뀌면 이전 자녀의 값이 보이지 않게 비운다.
    if (_loadedChildId != childProfileId) {
      _month = null;
      _loadedChildId = childProfileId;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final month = await _attendanceService.fetchMonthly(childProfileId);
      // 기다리는 사이 다른 자녀로 바뀌었거나 더 새로운 조회가 시작됐다면 이 결과는 버린다.
      if (_loadedChildId != childProfileId || seq != _loadSeq) return;
      _month = month;
    } on ApiException catch (error) {
      if (_loadedChildId == childProfileId && seq == _loadSeq) _errorMessage = error.message;
    } finally {
      if (_loadedChildId == childProfileId && seq == _loadSeq) _isLoading = false;
      notifyListeners();
    }
  }

  /// 도장 찍기. 서버가 멱등하게 처리하므로("같은 날 몇 번 호출해도 안전"),
  /// 이미 출석한 날에도 다시 눌러 최신 상태를 받아오는 것 자체는 안전하다.
  ///
  /// 성공하면 이번 달 현황을 다시 불러온 뒤 결과를, 실패하면 null을 돌려준다.
  Future<AttendanceCheckResult?> checkIn(int childProfileId) async {
    if (_isChecking) return null;

    _isChecking = true;
    _checkInError = null;
    notifyListeners();

    try {
      final result = await _attendanceService.checkIn(childProfileId);
      await load(childProfileId, force: true);
      return result;
    } on ApiException catch (error) {
      _checkInError = error.message;
      return null;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}
