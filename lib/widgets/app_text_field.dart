import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 네이비 배경 위에서 쓰는 공통 입력창.
/// 인증 화면들이 같은 모양을 써야 해서 한곳에 모아뒀다.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  /// 회원가입처럼 단계가 넘어가면 앞 단계 입력을 잠가야 할 때 쓴다.
  final bool enabled;

  /// 입력창 아래에 붙는 안내. 비밀번호 규칙처럼 라벨에 넣기엔 긴 설명을 여기 둔다.
  /// (라벨에 넣으면 좁은 기기에서 입력창 폭을 넘친다)
  final String? helperText;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        helperText: helperText,
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        // 안내가 길면 한 줄에서 잘리므로 두 줄까지 허용한다.
        helperMaxLines: 2,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.yellowColor, width: 2),
        ),
        // 잠긴 입력창도 값은 읽혀야 하므로 테두리만 흐리게 둔다.
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}
