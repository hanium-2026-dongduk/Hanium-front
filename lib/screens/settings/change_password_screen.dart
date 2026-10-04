import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';

/// P-TU-ST06 비밀번호 변경 화면.
///
/// 로그인 상태이므로 이메일 인증 없이 현재 비밀번호로 본인 확인을 대신한다
/// (`PUT /auth/password/change`, UC-ST-03). 현재 비밀번호가 틀리면 서버 메시지를
/// 그대로 보여주고 머무른다.
///
/// 성공하면 서버가 그 계정의 refresh token을 전부 폐기하므로, 다이얼로그로
/// 안내한 뒤 로컬 세션도 정리(logout)한다. AuthGate가 로그인 화면으로 바꿔주는
/// 순간 이 화면을 포함한 인증된 쪽 네비게이션 스택 전체가 사라지므로, 안내는
/// 화면이 사라지기 전에 다이얼로그로 먼저 보여준다(SnackBar는 그 시점에 화면이
/// 이미 없어져 표시되지 않을 수 있다).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// 서버 정책 검사에 더해, 지금 쓰는 비밀번호와 같으면 바꿀 의미가 없으므로 막는다.
  String? _validateNewPassword(String? value) {
    final error = Validators.password(value);
    if (error != null) return error;
    if (value == _currentPasswordController.text) {
      return '지금 쓰는 비밀번호와 다르게 정해 주세요.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final done = await auth.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _passwordController.text,
    );
    if (!done || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('비밀번호가 변경되었어요'),
        content: const Text('보안을 위해 로그아웃되었어요.\n새 비밀번호로 다시 로그인해 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '지금 쓰는 비밀번호를 확인한 뒤 새 비밀번호로 바꿔요.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _currentPasswordController,
                  label: '현재 비밀번호',
                  obscureText: true,
                  validator: (value) => Validators.required(value, '현재 비밀번호'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: '새 비밀번호',
                  helperText: '8자 이상, 영문·숫자·특수문자를 각각 넣어 주세요.',
                  obscureText: true,
                  validator: _validateNewPassword,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordConfirmController,
                  label: '새 비밀번호 확인',
                  obscureText: true,
                  validator: (value) => value == _passwordController.text
                      ? null
                      : '비밀번호가 일치하지 않아요.',
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    auth.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: auth.isSubmitting ? null : _submit,
                    child: auth.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.navyColor,
                            ),
                          )
                        : const Text('비밀번호 바꾸기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
