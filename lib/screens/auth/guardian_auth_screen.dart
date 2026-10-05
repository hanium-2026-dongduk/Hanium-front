import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/screens/parent_screen.dart';
import 'package:hanium_front/widgets/app_text_field.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart'; // 에러 처리를 위해 추가
import 'package:hanium_front/services/guardian_service.dart';
import 'package:hanium_front/providers/guardian_provider.dart';

enum AuthStep { loading, checkPin, inputPassword, setupPin, inputPin, error }

class GuardianAuthScreen extends StatefulWidget {
  const GuardianAuthScreen({super.key});

  @override
  State<GuardianAuthScreen> createState() => _GuardianAuthScreenState();
}

class _GuardianAuthScreenState extends State<GuardianAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();

  AuthStep _step = AuthStep.loading;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _reauthToken;

  @override
  void initState() {
    super.initState();
    _checkGuardianSettings();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // 1. 보호자 설정 조회 (has_pin 여부 확인)
  Future<void> _checkGuardianSettings() async {
    setState(() {
      _step = AuthStep.loading;
      _errorMessage = null;
    });

    try {
      final guardianService = context.read<GuardianService>();
      final setting = await guardianService.getSettings();
      final bool hasPin = setting['has_pin'] ?? false;

      setState(() {
        _step = hasPin ? AuthStep.inputPin : AuthStep.inputPassword;
      });
    } catch (e) {
      setState(() {
        _step = AuthStep.error;
        _errorMessage = '설정을 불러오지 못했습니다.';
      });
    }
  }

  // 버튼 클릭 시 분기 처리
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      switch (_step) {
        case AuthStep.inputPassword:
          await _verifyPassword();
          break;
        case AuthStep.setupPin:
          await _setupNewPin();
          break;
        case AuthStep.inputPin:
          await _verifyPin();
          break;
        default:
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 2. [최초 설정] 비밀번호 확인
  Future<void> _verifyPassword() async {
    try {
      final guardianService = context.read<GuardianService>();
      final token = await guardianService.verifyPassword(_textController.text);
      _reauthToken = token;

      setState(() {
        _step = AuthStep.setupPin;
        _textController.clear();
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        setState(() => _errorMessage = '연속 5회 실패하여 10분간 잠겼습니다.');
      } else {
        setState(() => _errorMessage = '비밀번호가 일치하지 않습니다.');
      }
    } catch (e) {
      setState(() => _errorMessage = '알 수 없는 오류가 발생했습니다.');
    }
  }

  // 3. [최초 설정] 새로운 PIN 설정
  Future<void> _setupNewPin() async {
    try {
      final guardianService = context.read<GuardianService>();
      await guardianService.setupPin(
        pin: _textController.text,
        reauthToken: _reauthToken,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'PIN 설정에 실패했습니다.');
    }
  }

  // 4. [기존 PIN 있음] PIN 검증
  Future<void> _verifyPin() async {
    try {
      final guardianService = context.read<GuardianService>();
      final guardianToken = await guardianService.verifyPin(_textController.text);

      if (mounted) {
        context.read<GuardianProvider>().setToken(guardianToken);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentScreen()),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        setState(() => _errorMessage = '연속 5회 실패하여 10분간 잠겼습니다.');
      } else {
        setState(() => _errorMessage = 'PIN이 틀렸습니다.');
      }
    } catch (e) {
      setState(() => _errorMessage = '알 수 없는 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('보호자 인증', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case AuthStep.loading:
      case AuthStep.checkPin:
        return const Center(child: CircularProgressIndicator(color: AppTheme.pastelGreen));

      case AuthStep.error:
        return Column(
          children: [
            Text(_errorMessage ?? '오류가 발생했습니다.', style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkGuardianSettings,
              child: const Text('다시 시도'),
            )
          ],
        );

      case AuthStep.inputPassword:
        return _buildForm(
          title: '보호자 계정 비밀번호',
          subtitle: '최초 PIN 설정을 위해 계정 비밀번호를 입력해주세요.',
          label: '계정 비밀번호',
          isNumeric: false,
        );

      case AuthStep.setupPin:
        return _buildForm(
          title: '새로운 PIN 설정',
          subtitle: '보호자 모드에서 사용할 4~6자리 PIN을 설정해주세요.',
          label: '새 PIN (4~6자리 숫자)',
          isNumeric: true,
        );

      case AuthStep.inputPin:
        return _buildForm(
          title: '보호자 PIN 입력',
          subtitle: '보호자 모드에 진입하려면 PIN을 입력해주세요.',
          label: '보호자 PIN',
          isNumeric: true,
          // ✨ PIN 잊음 버튼 추가
          bottomWidget: TextButton(
            onPressed: () {
              setState(() {
                _step = AuthStep.inputPassword; // 비밀번호 입력(재설정) 단계로 이동
                _errorMessage = null;
                _textController.clear();
              });
            },
            child: const Text(
              'PIN을 잊으셨나요? (비밀번호로 재설정)',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
    }
  }

  Widget _buildForm({
    required String title,
    required String subtitle,
    required String label,
    required bool isNumeric,
    Widget? bottomWidget,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(isNumeric ? Icons.dialpad : Icons.lock, size: 64, color: AppTheme.pastelGreen),
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 32),

          AppTextField(
            controller: _textController,
            label: label,
            obscureText: true,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '$label을(를) 입력해주세요.';
              }
              if (isNumeric && (value.length < 4 || value.length > 6)) {
                return '4~6자리 숫자로 입력해주세요.';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.navyColor,
                ),
              )
                  : const Text('확인'),
            ),
          ),

          if (bottomWidget != null) ...[
            const SizedBox(height: 16),
            bottomWidget,
          ],
        ],
      ),
    );
  }
}
