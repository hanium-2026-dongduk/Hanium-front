import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/child_profile.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../main_screen.dart';
import '../settings/account_security_screen.dart';

/// P-AU-AU04 자녀 프로필 관리 화면. 활성 프로필 전환이 곧 P-PT-PD01(자녀 선택)이라
/// 로그인 직후 이 화면이 그 역할도 겸한다(별도 선택 화면 없음).
///
/// 목록은 이 화면 안에서만 쓰는 상태라 Provider까지 올리지 않고 StatefulWidget으로 둔다.
/// 여러 화면이 프로필을 공유하게 되면 그때 ProfileProvider로 승격하면 된다.
class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({super.key});

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  List<ChildProfile> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    // 다른 동작(삭제·전환) 뒤에 이어서 불리므로, 그 사이 화면이 사라졌을 수 있다.
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profiles = await context.read<ProfileService>().fetchProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  /// 추가와 수정이 같은 입력 폼을 쓴다. [existing]이 없으면 추가 모드.
  Future<void> _openEditor({ChildProfile? existing}) async {
    final draft = await showModalBottomSheet<ChildProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navyColor,
      builder: (_) => _ProfileEditorSheet(existing: existing),
    );
    if (draft == null || !mounted) return;

    final service = context.read<ProfileService>();
    try {
      if (existing == null) {
        await service.createProfile(draft);
      } else {
        await service.updateProfile(draft);
      }
      await _loadProfiles();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  /// 활성 프로필 전환은 전용 API로만 되고, 한 번에 한 명만 활성일 수 있다.
  /// 전환에 성공하면 곧바로 메인 화면으로 들어간다.
  Future<void> _activateProfile(ChildProfile profile) async {
    try {
      final activated = await context.read<ProfileService>().activateProfile(
        profile.childProfileId,
      );
      if (!mounted) return;
      _enterMainScreen(activated);
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  /// 이미 활성인 프로필을 다시 탭했을 때도 같은 경로로 메인 화면에 들어간다.
  void _enterMainScreen(ChildProfile profile) {
    context.read<ActiveChildProvider>().setActiveChild(profile);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainScreen()),
    );
  }

  Future<void> _deleteProfile(ChildProfile profile) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '프로필 삭제',
      content: '${profile.childName} 프로필을 삭제할까요?\n학습 기록도 함께 사라져요.',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ProfileService>().deleteProfile(
        profile.childProfileId,
      );
      await _loadProfiles();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // 서버 users에 이름 컬럼이 없어서 계정 식별은 이메일로 보여준다.
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? '자녀 프로필' : user.email),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccountSecurityScreen(),
              ),
            ),
            icon: const Icon(Icons.security_outlined),
            tooltip: '계정 보안',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppTheme.yellowColor,
        foregroundColor: AppTheme.navyColor,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(onRefresh: _loadProfiles, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return AsyncStateView(
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _loadProfiles,
      isEmpty: _profiles.isEmpty,
      emptyMessage: '아직 등록된 자녀 프로필이 없어요.\n+ 버튼으로 추가해 주세요.',
      contentBuilder: (_) => _buildProfileList(),
    );
  }

  Widget _buildProfileList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final profile = _profiles[index];
        return Card(
          color: Colors.white.withValues(alpha: profile.isActive ? 0.16 : 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: profile.isActive
                ? const BorderSide(color: AppTheme.yellowColor, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            // 비활성 프로필을 누르면 활성으로 전환한다.
            // 이미 활성인 프로필을 탭하면 바로 메인 화면으로, 아니면 먼저 전환한다.
            onTap: profile.isActive
                ? () => _enterMainScreen(profile)
                : () => _activateProfile(profile),
            leading: CircleAvatar(
              backgroundColor: AppTheme.yellowColor,
              foregroundImage:
                  (profile.profileImageUrl != null &&
                      profile.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(profile.profileImageUrl!)
                  : null,
              child: const Icon(Icons.child_care, color: AppTheme.navyColor),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    profile.childName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (profile.isActive) ...[
                  const SizedBox(width: 8),
                  const _ActiveBadge(),
                ],
              ],
            ),
            subtitle: Text(
              _describe(profile),
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _openEditor(existing: profile),
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  tooltip: '수정',
                ),
                IconButton(
                  onPressed: () => _deleteProfile(profile),
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  tooltip: '삭제',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 나이는 선택 항목이라 없을 수 있어서 학습 수준과 묶어 한 줄로 보여준다.
String _describe(ChildProfile profile) {
  final age = profile.age;
  return age == null
      ? profile.learningLevel.label
      : '$age살 · ${profile.learningLevel.label}';
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.yellowColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '사용 중',
        style: TextStyle(
          color: AppTheme.navyColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProfileEditorSheet extends StatefulWidget {
  final ChildProfile? existing;

  const _ProfileEditorSheet({this.existing});

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late LearningLevel _learningLevel;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.childName ?? '');
    _ageController = TextEditingController(
      text: existing?.age?.toString() ?? '',
    );
    _learningLevel = existing?.learningLevel ?? LearningLevel.beginner;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageController.text.trim());
    final existing = widget.existing;

    Navigator.of(context).pop(
      existing == null
          ? ChildProfile(
              // 서버가 채워주므로 요청에는 담기지 않는다.
              childProfileId: 0,
              childName: _nameController.text.trim(),
              age: age,
              learningLevel: _learningLevel,
            )
          : existing.copyWith(
              childName: _nameController.text.trim(),
              age: age,
              learningLevel: _learningLevel,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 키보드가 올라와도 입력창이 가려지지 않도록 여백을 맞춘다.
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? '자녀 프로필 추가' : '프로필 수정',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _nameController,
              label: '이름',
              validator: Validators.childName,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _ageController,
              label: '나이 (선택, 1~15)',
              keyboardType: TextInputType.number,
              validator: Validators.childAge,
            ),
            const SizedBox(height: 16),
            _LearningLevelPicker(
              value: _learningLevel,
              onChanged: (level) => setState(() => _learningLevel = level),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.existing == null ? '추가하기' : '저장하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningLevelPicker extends StatelessWidget {
  final LearningLevel value;
  final ValueChanged<LearningLevel> onChanged;

  const _LearningLevelPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('학습 수준', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        SegmentedButton<LearningLevel>(
          segments: LearningLevel.values
              .map(
                (level) => ButtonSegment<LearningLevel>(
                  value: level,
                  label: Text(level.label),
                ),
              )
              .toList(),
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

