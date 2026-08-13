import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/child_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';

/// P-AU-AU04 자녀 프로필 관리 화면.
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
    final draft = await showModalBottomSheet<_ProfileDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navyColor,
      builder: (_) => _ProfileEditorSheet(existing: existing),
    );
    if (draft == null || !mounted) return;

    final service = context.read<ProfileService>();
    try {
      if (existing == null) {
        await service.createProfile(
          name: draft.name,
          birthDate: draft.birthDate,
        );
      } else {
        await service.updateProfile(
          ChildProfile(
            id: existing.id,
            name: draft.name,
            birthDate: draft.birthDate,
            avatarKey: existing.avatarKey,
          ),
        );
      }
      await _loadProfiles();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _deleteProfile(ChildProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('프로필 삭제'),
        content: Text('${profile.name} 프로필을 삭제할까요?\n학습 기록도 함께 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ProfileService>().deleteProfile(profile.id);
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
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? '자녀 프로필' : '${user.name}님의 자녀'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _CenteredMessage(
        message: _errorMessage!,
        actionLabel: '다시 시도',
        onAction: _loadProfiles,
      );
    }

    if (_profiles.isEmpty) {
      return const _CenteredMessage(message: '아직 등록된 자녀 프로필이 없어요.\n+ 버튼으로 추가해 주세요.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final profile = _profiles[index];
        return Card(
          color: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              backgroundColor: AppTheme.yellowColor,
              child: Icon(Icons.child_care, color: AppTheme.navyColor),
            ),
            title: Text(
              profile.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: profile.birthDate == null
                ? null
                : Text(
                    _formatDate(profile.birthDate!),
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

String _formatDate(DateTime date) =>
    '${date.year}년 ${date.month}월 ${date.day}일';

/// 편집 시트가 화면으로 돌려주는 입력값 묶음.
class _ProfileDraft {
  final String name;
  final DateTime? birthDate;

  const _ProfileDraft({required this.name, this.birthDate});
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
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _birthDate = widget.existing?.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 6),
      firstDate: DateTime(now.year - 15),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ProfileDraft(name: _nameController.text.trim(), birthDate: _birthDate),
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
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.cake_outlined, color: Colors.white70),
              label: Text(
                _birthDate == null ? '생년월일 선택 (선택)' : _formatDate(_birthDate!),
                style: const TextStyle(color: Colors.white70),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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

class _CenteredMessage extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator가 동작하려면 스크롤 가능한 자식이 있어야 한다.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
