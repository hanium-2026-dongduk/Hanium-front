import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';

/// 재설정 진행 단계.
enum _ResetStep { email, reset }

/// P-AU-AU03 비밀번호 재설정 화면.
///
/// 서버 계약상 2단계다. (Hanium-back `docs/API_SPEC_AUTH.md` 7절)
///   1. 이메일로 인증번호 발송   POST /auth/password/reset-request
///   2. 인증번호 + 새 비밀번호   PUT  /auth/password/reset
///
/// 회원가입과 달리 "인증번호만 확인하는" 단계가 없다. 서버가 검증과 변경을 한 트랜잭션으로
/// 처리하기 때문에, 인증번호와 새 비밀번호를 같은 화면에서 함께 받는다.
///
/// 로그인 ID가 곧 이메일이라 별도의 "아이디 찾기"는 요구사항에 없다.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  _ResetStep _step = _ResetStep.email;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    switch (_step) {
      case _ResetStep.email:
        if (await auth.sendPasswordResetCode(_email) && mounted) {
          setState(() => _step = _ResetStep.reset);
        }
      case _ResetStep.reset:
        final done = await auth.resetPassword(
          email: _email,
          code: _codeController.text.trim(),
          newPassword: _passwordController.text,
        );
        if (done && mounted) {
          // 서버가 기존 세션을 모두 끊으므로 새 비밀번호로 다시 로그인해야 한다.
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요.')),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isEmailStep = _step == _ResetStep.email;

    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 재설정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEmailStep
                      ? '가입할 때 쓴 이메일을 알려주시면 인증번호를 보내드려요.'
                      : '메일로 받은 숫자 6자리와 새로 쓸 비밀번호를 입력해 주세요.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _emailController,
                  label: '이메일',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  // 인증번호를 받은 주소로만 바꿀 수 있어서 이후 단계에서는 잠근다.
                  enabled: isEmailStep,
                ),
                if (!isEmailStep) ...[
                  const SizedBox(height: 16),
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
                        : Text(isEmailStep ? '인증번호 받기' : '비밀번호 바꾸기'),
                  ),
                ),
                if (isEmailStep) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '가입되지 않은 이메일이어도 같은 안내가 보여요.\n메일이 오지 않으면 주소를 다시 확인해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
