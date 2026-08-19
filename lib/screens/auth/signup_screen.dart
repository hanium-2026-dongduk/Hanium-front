import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';

/// 회원가입 진행 단계. 서버가 이메일 인증을 마친 계정만 가입시켜 준다.
enum _SignupStep { email, code, password }

/// P-AU-AU02 회원가입 화면.
///
/// 서버 계약상 가입은 3단계다. (Hanium-back `docs/API_SPEC_AUTH.md`)
///   1. 이메일로 인증번호 발송  POST /auth/email/send
///   2. 인증번호 확인          POST /auth/email/verify
///   3. 비밀번호 정하고 가입    POST /auth/signup
///
/// 가입 응답에는 토큰이 없어서 AuthProvider가 곧바로 로그인까지 이어 준다.
/// 서버 users에 이름 컬럼이 없으므로 보호자 이름은 받지 않는다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  _SignupStep _step = _SignupStep.email;

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
      case _SignupStep.email:
        if (await auth.sendSignupCode(_email) && mounted) {
          setState(() => _step = _SignupStep.code);
          _showMessage('인증번호를 보냈어요. 5분 안에 입력해 주세요.');
        }
      case _SignupStep.code:
        final verified = await auth.verifySignupCode(
          email: _email,
          code: _codeController.text.trim(),
        );
        if (verified && mounted) {
          setState(() => _step = _SignupStep.password);
        }
      case _SignupStep.password:
        final joined = await auth.signup(
          email: _email,
          password: _passwordController.text,
        );
        // 이 화면은 로그인 화면 위에 쌓여 있어서, 닫아줘야 AuthGate가 그린 다음 화면이 보인다.
        if (joined && mounted) {
          Navigator.of(context).pop();
        }
    }
  }

  Future<void> _resendCode() async {
    if (await context.read<AuthProvider>().sendSignupCode(_email) && mounted) {
      _showMessage('인증번호를 다시 보냈어요.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _actionLabel => switch (_step) {
    _SignupStep.email => '인증번호 받기',
    _SignupStep.code => '인증번호 확인',
    _SignupStep.password => '가입하기',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepIndicator(step: _step),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _emailController,
                  label: '이메일',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  // 인증을 마친 이메일로만 가입되므로 이후 단계에서는 못 바꾸게 한다.
                  enabled: _step == _SignupStep.email,
                ),
                if (_step != _SignupStep.email) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _codeController,
                    label: '인증번호 6자리',
                    keyboardType: TextInputType.number,
                    validator: Validators.verificationCode,
                    enabled: _step == _SignupStep.code,
                  ),
                ],
                if (_step == _SignupStep.code)
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
                if (_step == _SignupStep.password) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: '비밀번호 (8자 이상, 영문+숫자+특수문자)',
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordConfirmController,
                    label: '비밀번호 확인',
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
                        : Text(_actionLabel),
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

/// 지금 몇 단계인지 알려주는 안내 문구.
class _StepIndicator extends StatelessWidget {
  final _SignupStep step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final (number, guide) = switch (step) {
      _SignupStep.email => (1, '가입할 이메일을 입력하면 인증번호를 보내드려요.'),
      _SignupStep.code => (2, '메일로 받은 숫자 6자리를 입력해 주세요.'),
      _SignupStep.password => (3, '마지막이에요. 사용할 비밀번호를 정해 주세요.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number / 3 단계',
          style: const TextStyle(
            color: AppTheme.yellowColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(guide, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
