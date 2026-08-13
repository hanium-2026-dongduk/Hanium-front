import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';

/// P-AU-AU02 회원가입 화면.
/// 가입에 성공하면 서버가 바로 토큰을 주므로 곧장 로그인 상태가 된다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final succeeded = await context.read<AuthProvider>().signup(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );

    // 이 화면은 로그인 화면 위에 쌓여 있어서, 닫아줘야 AuthGate가 그린 다음 화면이 보인다.
    if (succeeded && mounted) {
      Navigator.of(context).pop();
    }
  }

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
                AppTextField(
                  controller: _nameController,
                  label: '보호자 이름',
                  validator: Validators.name,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  label: '이메일',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: '비밀번호 (8자 이상)',
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
                        : const Text('가입하기'),
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
