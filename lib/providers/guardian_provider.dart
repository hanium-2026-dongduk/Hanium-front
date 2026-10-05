import 'package:flutter/material.dart';

class GuardianProvider extends ChangeNotifier {
  String? _guardianToken;

  String? get guardianToken => _guardianToken;

  // 토큰이 있는지(인증되었는지) 확인하는 편의 기능
  bool get isAuthenticated => _guardianToken != null;

  // 인증 성공 시 토큰 저장
  void setToken(String token) {
    _guardianToken = token;
    notifyListeners();
  }

  // 로그아웃 하거나 10분 지나서 만료될 때 토큰 삭제
  void clearToken() {
    _guardianToken = null;
    notifyListeners();
  }
}
