import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('앱 정보 및 약관', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // [ST04] 앱 정보 확인
          _buildSectionTitle('앱 정보'),
          _buildListTile(
            title: '버전 정보 / 제작사',
            subtitle: 'v1.0.0 (최신 버전) / Hanium Team',
            icon: Icons.info_outline,
            onTap: () => _showSimpleDialog(context, '버전 정보', '현재 최신 버전(v1.0.0)을 사용 중입니다.'),
          ),
          _buildListTile(
            title: '오픈소스 라이선스',
            subtitle: '사용된 오픈소스 라이선스 정보 표시',
            icon: Icons.code,
            onTap: () {
              // ✨ 플러터가 자동으로 사용된 패키지 라이선스를 모아서 보여주는 마법의 코드!
              showLicensePage(
                context: context,
                applicationName: '매직북 (Magic Book)',
                applicationVersion: 'v1.0.0',
                applicationLegalese: '© 2026 Hanium Team. All rights reserved.',
              );
            },
          ),

          const SizedBox(height: 32),

          // [ST05] 약관 및 정책
          _buildSectionTitle('약관 및 정책'),
          _buildListTile(
            title: '개인정보 처리방침',
            subtitle: '개인정보 수집/사용/관리 방침',
            icon: Icons.privacy_tip_outlined,
            onTap: () => _showPolicyDialog(context, '개인정보 처리방침', _privacyPolicyText),
          ),
          _buildListTile(
            title: '서비스 이용약관',
            subtitle: '매직북 서비스 이용약관 확인',
            icon: Icons.description_outlined,
            onTap: () => _showPolicyDialog(context, '서비스 이용약관', _termsOfServiceText),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.pastelGreen, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildListTile({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: Colors.white70, size: 28),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        onTap: onTap,
      ),
    );
  }

  // 간단한 알림용 다이얼로그
  void _showSimpleDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyColor,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: AppTheme.pastelGreen)),
          ),
        ],
      ),
    );
  }

  // 내용이 긴 약관용 스크롤 다이얼로그
  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: AppTheme.pastelGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// --- 실제 서비스 느낌을 살린 기본 약관 텍스트 데이터 ---

const String _privacyPolicyText = '''
제1조 (수집하는 개인정보 항목)
매직북은 서비스 제공을 위해 아래와 같은 개인정보를 수집하고 있습니다.
- 필수항목: 보호자 이메일, 자녀 프로필 정보 (이름/닉네임, 나이)
- 서비스 이용 기록: 동화 열람 이력, 학습 시간, 퀴즈 정답률 등

제2조 (개인정보의 수집 및 이용 목적)
수집된 정보는 다음의 목적을 위해 활용됩니다.
1. AI 맞춤형 동화 생성 및 학습 레벨 조정
2. 보호자 대시보드를 통한 자녀 학습 현황 통계 제공
3. 서비스 기능 개선 및 신규 콘텐츠 기획

제3조 (개인정보의 보관 및 파기)
원칙적으로 회원의 개인정보는 회원 탈퇴 시 지체 없이 파기됩니다. 단, 관련 법령에 의해 보존할 필요가 있는 경우 법령에서 정한 기간 동안 보관합니다.

제4조 (어린이 개인정보 보호)
매직북은 만 14세 미만 아동의 정보를 수집할 때 반드시 법정대리인(보호자)의 동의를 받으며, 아동의 개인정보를 보호하기 위해 최선을 다합니다.
''';

const String _termsOfServiceText = '''
제1조 (목적)
본 약관은 Hanium Team이 제공하는 '매직북(Magic Book)' 서비스의 이용 조건 및 절차, 회원과 회사 간의 권리와 의무를 규정함을 목적으로 합니다.

제2조 (서비스의 제공)
1. 회사는 AI 기술을 활용하여 어린이 맞춤형 동화를 생성하고 학습 현황을 관리하는 서비스를 제공합니다.
2. 서비스는 연중무휴 1일 24시간 제공함을 원칙으로 하나, 시스템 점검 등의 이유로 일시 중단될 수 있습니다.

제3조 (회원의 의무)
1. 회원은 서비스 이용 시 타인의 정보를 도용하거나 허위 정보를 등록해서는 안 됩니다.
2. 회원은 AI 동화 생성 기능을 남용하여 불건전하거나 타인에게 불쾌감을 주는 콘텐츠를 생성하도록 유도해서는 안 됩니다.

제4조 (책임 제한)
1. 회사는 AI가 생성한 동화 내용의 완벽한 정확성이나 특정 목적에의 적합성을 보장하지 않습니다.
2. 천재지변, 서버 장애 등 불가항력적인 사유로 서비스가 중단된 경우 회사는 그 책임을 면합니다.
''';
