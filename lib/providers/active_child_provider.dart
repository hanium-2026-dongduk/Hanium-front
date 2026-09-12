import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/child_profile.dart';
import '../services/profile_service.dart';

/// 활성 자녀 프로필을 앱 전체가 공유하기 위한 Provider.
///
/// 단어장·보상 API가 전부 `child_profile_id`를 요구하는데, 그 값을 화면마다
/// 따로 구하지 않도록 한곳에서 관리한다. 활성 프로필은 `ProfileService`의
/// `isActive` 플래그(한 보호자에 항상 최대 1개)로 판별한다.
enum ActiveChildStatus { unknown, ready, none, error }

class ActiveChildProvider extends ChangeNotifier {
  final ProfileService _profileService;

  ActiveChildProvider({required ProfileService profileService})
    : _profileService = profileService;

  ActiveChildStatus _status = ActiveChildStatus.unknown;
  ChildProfile? _activeChild;
  String? _errorMessage;

  ActiveChildStatus get status => _status;
  ChildProfile? get activeChild => _activeChild;
  int? get childProfileId => _activeChild?.childProfileId;
  String? get errorMessage => _errorMessage;

  /// 로그인 직후, 그리고 프로필 전환 뒤에 호출해 활성 자녀를 다시 구한다.
  Future<void> load() async {
    try {
      final profiles = await _profileService.fetchProfiles();
      ChildProfile? active;
      for (final profile in profiles) {
        if (profile.isActive) {
          active = profile;
          break;
        }
      }
      _activeChild = active;
      _status = _activeChild != null ? ActiveChildStatus.ready : ActiveChildStatus.none;
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _status = ActiveChildStatus.error;
    }
    notifyListeners();
  }

  /// 프로필 선택 화면에서 자녀를 고른 직후 곧바로 반영할 때 쓴다.
  void setActiveChild(ChildProfile profile) {
    _activeChild = profile;
    _status = ActiveChildStatus.ready;
    _errorMessage = null;
    notifyListeners();
  }

  void clear() {
    _activeChild = null;
    _status = ActiveChildStatus.unknown;
    notifyListeners();
  }
}
