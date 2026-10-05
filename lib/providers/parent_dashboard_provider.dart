import 'package:flutter/foundation.dart';
import '../core/api_exception.dart';
import '../models/child_profile.dart';
import '../models/dashboard_summary.dart';
import '../services/profile_service.dart';
import '../services/dashboard_service.dart';
import '../services/usage_service.dart';
import '../services/guardian_service.dart';
import '../services/sticker_service.dart';

class ParentDashboardProvider extends ChangeNotifier {
  final ProfileService profileService;
  final DashboardService dashboardService;
  final UsageService usageService;
  final GuardianService guardianService;
  final StickerService stickerService;

  ParentDashboardProvider({
    required this.profileService,
    required this.dashboardService,
    required this.usageService,
    required this.guardianService,
    required this.stickerService,
  });

  bool _isLoading = false;
  String? _errorMessage;

  List<ChildProfile> _children = [];
  ChildProfile? _selectedChild;

  DashboardSummary? _dashboardSummary;
  Map<String, dynamic>? _usageData;
  Map<String, dynamic>? _guardianSettings;
  List<dynamic> _stickers = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ChildProfile> get children => _children;
  ChildProfile? get selectedChild => _selectedChild;
  DashboardSummary? get dashboardSummary => _dashboardSummary;
  Map<String, dynamic>? get usageData => _usageData;
  Map<String, dynamic>? get guardianSettings => _guardianSettings;
  List<dynamic> get stickers => _stickers;

  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        profileService.fetchProfiles(),
        guardianService.getSettings(),
        stickerService.fetchStickerCatalog(),
      ]);

      _children = results[0] as List<ChildProfile>;
      _guardianSettings = results[1] as Map<String, dynamic>;
      _stickers = (results[2] as Map<String, dynamic>)['stickers'] ?? [];

      if (_children.isNotEmpty) {
        await selectChild(_children.first);
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '초기 데이터를 불러오지 못했습니다.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectChild(ChildProfile child) async {
    _selectedChild = child;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        dashboardService.fetchSummary(child.childProfileId),
        usageService.getTodayUsage(child.childProfileId),
      ]);

      _dashboardSummary = results[0] as DashboardSummary;
      _usageData = results[1] as Map<String, dynamic>;

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '자녀 데이터를 불러오지 못했습니다.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendSticker(int childId, String stickerCode, String? message) async {
    try {
      await stickerService.sendSticker(
        childId: childId,
        stickerCode: stickerCode,
        message: message,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
