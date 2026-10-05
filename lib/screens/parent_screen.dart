import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/providers/parent_dashboard_provider.dart';
import 'package:hanium_front/models/child_profile.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  bool isWeeklyStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentDashboardProvider>().loadInitialData();
    });
  }

  // PD04: 칭찬 스티커 바텀 시트
  void _showStickerSheet(BuildContext context, ParentDashboardProvider provider, ChildProfile child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navyColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${child.childName}에게 칭찬 스티커 보내기', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: provider.stickers.map((sticker) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final success = await provider.sendSticker(child.childProfileId, sticker['sticker_code'], '참 잘했어요!');

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? '스티커를 보냈어요!' : '스티커 발송에 실패했습니다.')),
                      );
                    },
                    child: Column(
                      children: [
                        const CircleAvatar(radius: 30, backgroundColor: AppTheme.yellowColor, child: Icon(Icons.star, color: Colors.orange)),
                        const SizedBox(height: 8),
                        Text(sticker['name'] ?? '', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParentDashboardProvider>();

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('보호자 대시보드', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: provider.isLoading && provider.children.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.yellowColor))
            : provider.errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(provider.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => provider.loadInitialData(), child: const Text('다시 시도')),
            ],
          ),
        )
            : _buildDashboardContent(context, provider),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, ParentDashboardProvider provider) {
    if (provider.children.isEmpty) {
      return const Center(child: Text('등록된 자녀 프로필이 없습니다.', style: TextStyle(color: Colors.white70)));
    }

    final selectedChild = provider.selectedChild;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      child: Column(
        children: [
          // 1. 자녀 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('자녀 프로필 선택', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ChildProfile>(
                    value: selectedChild,
                    dropdownColor: AppTheme.navyColor,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    onChanged: (ChildProfile? newValue) {
                      if (newValue != null) provider.selectChild(newValue);
                    },
                    items: provider.children.map<DropdownMenuItem<ChildProfile>>((ChildProfile child) {
                      return DropdownMenuItem<ChildProfile>(
                        value: child,
                        child: Text('${child.childName} ${child.age != null ? '(${child.age})' : ''}'),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.pastelGreen)))
          else if (selectedChild != null)
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 4, child: _buildProfileCard(context, provider, selectedChild)),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(flex: 5, child: _buildUsageStatsCard(provider)), // PD02/03 사용 시간 연동
                        const SizedBox(height: 16),
                        Expanded(flex: 4, child: _buildSummaryCard(provider)), // PD02 대시보드 요약 연동
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, ParentDashboardProvider provider, ChildProfile child) {
    return _buildDashboardCard(
      title: '자녀 프로필 정보',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(radius: 52, backgroundColor: AppTheme.pastelGreen, child: Icon(Icons.face, size: 60, color: AppTheme.navyColor)),
          const SizedBox(height: 32),
          _buildInfoRow('자녀 이름', child.childName),
          const SizedBox(height: 20),
          _buildInfoRow('학습 수준', child.learningLevel.label),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showStickerSheet(context, provider, child), // 스티커 모달 연결
              icon: const Icon(Icons.star, color: AppTheme.yellowColor),
              label: const Text('칭찬 스티커 발송', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navyColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildUsageStatsCard(ParentDashboardProvider provider) {
    final accumulatedSeconds = provider.usageData?['accumulatedSeconds'] ?? 0;
    final limitSeconds = provider.usageData?['limitSeconds'] ?? 3600;
    final accumulatedMinutes = accumulatedSeconds ~/ 60;
    final limitMinutes = limitSeconds ~/ 60;
    final double progress = limitSeconds > 0 ? (accumulatedSeconds / limitSeconds).clamp(0.0, 1.0) : 0;

    return _buildDashboardCard(
      title: '🕒 오늘 사용 시간 (PD02)',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$accumulatedMinutes분 / $limitMinutes분', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            color: progress >= 1.0 ? Colors.redAccent : AppTheme.pastelGreen,
            minHeight: 12,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 16),
          Text(
            progress >= 1.0 ? '일일 사용 한도를 초과했습니다.' : '오늘도 꾸준히 학습 중이에요!',
            style: TextStyle(color: progress >= 1.0 ? Colors.redAccent : Colors.white70),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ParentDashboardProvider provider) {
    final summary = provider.dashboardSummary;
    return _buildDashboardCard(
      title: '📖 학습 데이터 요약 (PD02)',
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Wrap( // ✨ Row 대신 Wrap을 써서 공간이 부족하면 아래로 줄바꿈되도록 처리
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildStatBadge('완성한 동화: ${summary?.storyCount ?? 0}권', AppTheme.pastelBlue),
            _buildStatBadge('수집한 단어: ${summary?.vocabularyCount ?? 0}개', AppTheme.pastelGreen),
            _buildStatBadge('퀴즈 시도: ${summary?.quizStats.totalAttempts ?? 0}회', AppTheme.yellowColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}
