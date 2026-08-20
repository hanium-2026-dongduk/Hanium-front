import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';

/// 진행 단계. 로그인 상태라 이메일은 이미 알고 있어 [request]에서 곧바로
/// 인증번호 발송을 요청하고, 성공하면 [confirm]으로 넘어간다.
enum _Step { request, confirm }

/// P-TU-ST06 비밀번호 변경 화면.
///
/// 백엔드에는 "로그인 상태에서 현재 비밀번호로 바꾸는" 전용 API가 없고,
/// 이메일 인증번호 기반 재설정 API(AU03, `PasswordResetScreen`과 동일한
/// `POST /auth/password/reset-request` + `PUT /auth/password/reset`)만 있다.
/// 그래서 이 화면은 그 API를 그대로 재사용하되, 로그인된 사용자의 이메일을
/// 이미 알고 있으니 이메일 입력 단계를 생략한다.
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
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  _Step _step = _Step.request;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  String get _email => context.read<AuthProvider>().user?.email ?? '';

  Future<void> _requestCode() async {
    if (await context.read<AuthProvider>().sendPasswordResetCode(_email) &&
        mounted) {
      setState(() => _step = _Step.confirm);
    }
  }

  Future<void> _resendCode() async {
    if (await context.read<AuthProvider>().sendPasswordResetCode(_email) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증번호를 다시 보냈어요.')));
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final done = await auth.resetPassword(
      email: _email,
      code: _codeController.text.trim(),
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
    final isRequestStep = _step == _Step.request;

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
                Text(
                  isRequestStep
                      ? '$_email(으)로 인증번호를 보내드려요.'
                      : '메일로 받은 숫자 6자리와 새로 쓸 비밀번호를 입력해 주세요.',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (!isRequestStep) ...[
                  const SizedBox(height: 24),
                  AppTextField(
                    controller: _codeController,
                    label: '인증번호 6자리',
                    keyboardType: TextInputType.number,
                    validator: Validators.verificationCode,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: auth.isSubmitting ? null : _resendCode,
                      child: const Text(
                        '인증번호 다시 받기',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  AppTextField(
                    controller: _passwordController,
                    label: '새 비밀번호',
                    helperText: '8자 이상, 영문·숫자·특수문자를 각각 넣어 주세요.',
                    obscureText: true,
                    validator: Validators.password,
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
                ],
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
                    onPressed: auth.isSubmitting
                        ? null
                        : (isRequestStep ? _requestCode : _confirm),
                    child: auth.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.navyColor,
                            ),
                          )
                        : Text(isRequestStep ? '인증번호 받기' : '비밀번호 바꾸기'),
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
