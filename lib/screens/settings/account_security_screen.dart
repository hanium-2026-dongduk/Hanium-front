import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'change_password_screen.dart';

/// P-TU-ST06 계정 보안 화면.
///
/// 비밀번호 변경과 로그아웃을 한곳에 모아둔다. 두 동작 모두 별도 API를 새로
/// 만들지 않고 기존 AuthProvider(재설정 API·logout)를 그대로 쓴다.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthProvider>().logout();
    // AuthGate가 로그인 화면으로 바꿔주므로 여기서 직접 이동하지 않는다.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 보안')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.white70),
            title: const Text('비밀번호 변경', style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordScreen(),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
