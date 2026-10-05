import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/screens/story_setting_screen.dart';
import 'package:hanium_front/models/story_payload.dart';
import 'package:hanium_front/models/character.dart';
import 'package:hanium_front/providers/character_provider.dart';
import 'package:hanium_front/services/character_service.dart';
import 'package:hanium_front/widgets/async_state_view.dart';

/// 랜덤 생성용 캐릭터 후보. 백엔드가 내용을 대신 만들어 주지 않아 앱이 쥐고 있는다.
const _randomCharacterPool = [
  (name: '초롱이', personality: '호기심 많고 씩씩해요', description: '별빛 망토를 두른 작은 여우예요.'),
  (name: '몽실이', personality: '다정하고 느긋해요', description: '구름처럼 폭신한 하얀 강아지예요.'),
  (
    name: '반짝이',
    personality: '용감하고 장난기 많아요',
    description: '반짝이는 비늘을 가진 아기 용이에요.',
  ),
  (
    name: '토실이',
    personality: '겁이 많지만 마음이 따뜻해요',
    description: '당근을 좋아하는 통통한 토끼예요.',
  ),
];

class StoryCreationScreen extends StatelessWidget {
  const StoryCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✨ 현재 선택된 자녀의 ID를 가져옵니다.
    final childProfileId = context.read<ActiveChildProvider>().childProfileId;

    // 만약 자녀가 선택되지 않은 상태에서 이 화면에 들어왔다면 돌려보냅니다.
    if (childProfileId == null) {
      return const Scaffold(body: Center(child: Text('먼저 자녀 프로필을 선택해 주세요.')));
    }

    return ChangeNotifierProvider<CharacterProvider>(
      create: (context) => CharacterProvider(
        characterService: context.read<CharacterService>(),
        childProfileId: childProfileId, // ✨ 프로바이더 생성 시 ID를 넘겨줍니다.
      )..load(),
      child: const _StoryCreationView(),
    );
  }
}

class _StoryCreationView extends StatefulWidget {
  const _StoryCreationView();

  @override
  State<_StoryCreationView> createState() => _StoryCreationViewState();
}

class _StoryCreationViewState extends State<_StoryCreationView> {
  // --- [SG01] 동화 생성 상태 변수 ---
  String _selectedMethod = '기존 캐릭터 선택';
  int? _selectedCharacterId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personalityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // --- [SG02] 삽화 생성 상태 변수 ---
  String _selectedStyle = '아동풍';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _personalityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      if (method == '랜덤 생성' && _nameController.text.trim().isEmpty) {
        _rollRandomCharacter();
      }
    });
  }

  void _rollRandomCharacter() {
    final picked =
        _randomCharacterPool[Random().nextInt(_randomCharacterPool.length)];
    _nameController.text = picked.name;
    _personalityController.text = picked.personality;
    _descriptionController.text = picked.description;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleNext() async {
    final payload = StoryCreatePayload(
      characterMethod: _selectedMethod,
      imageStyle: _selectedStyle,
    );

    if (_selectedMethod == '기존 캐릭터 선택') {
      final characterId = _selectedCharacterId;
      if (characterId == null) {
        _showSnack('캐릭터를 선택해 주세요!');
        return;
      }
      final character = context
          .read<CharacterProvider>()
          .characters
          .where((c) => c.characterId == characterId)
          .firstOrNull;
      payload.characterId = characterId;
      payload.characterName = character?.name;
      payload.characterPersonality = character?.personality;
      payload.characterDescription = character?.description;
      _goToNextStep(payload);
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnack('캐릭터 이름을 입력해 주세요!');
      return;
    }

    setState(() => _isSubmitting = true);
    final created = await context.read<CharacterProvider>().create(
      name: _nameController.text.trim(),
      personality: _personalityController.text.trim().isEmpty
          ? '밝음'
          : _personalityController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedMethod == '랜덤 생성'
          ? CharacterType.random
          : CharacterType.custom,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created == null) {
      _showSnack(
        context.read<CharacterProvider>().createError ?? '캐릭터 생성에 실패했어요.',
      );
      return;
    }

    payload.characterId = created.characterId;
    payload.characterName = created.name;
    payload.characterPersonality = created.personality;
    payload.characterDescription = created.description;
    _goToNextStep(payload);
  }

  void _goToNextStep(StoryCreatePayload payload) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StorySettingScreen(payload: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ 새로운 동화 만들기'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 태블릿 대응: 전체 콘텐츠를 가운데 정렬하고 최대 너비(700) 제한
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // [SG01] 캐릭터 생성 방식 선택 영역
                // ==========================================
                _buildSectionTitle('1. 캐릭터를 어떻게 만들까요?'),
                const SizedBox(height: 16),
                // Expanded를 사용하여 3개의 카드가 화면 비율에 맞춰 고르게 분배됨
                Row(
                  children: [
                    Expanded(child: _buildMethodCard('직접 그리기', Icons.draw)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMethodCard('기존 캐릭터 선택', Icons.face)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMethodCard('랜덤 생성', Icons.casino)),
                  ],
                ),
                const SizedBox(height: 40),

                // ==========================================
                // [SG01] 캐릭터 세부 정보 입력/선택 영역
                // ==========================================
                if (_selectedMethod == '기존 캐릭터 선택') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('2. 어떤 캐릭터로 할까요?'),
                      Consumer<CharacterProvider>(
                        builder: (context, characters, _) => TextButton.icon(
                          onPressed: characters.isLoading
                              ? null
                              : characters.load,
                          icon: const Icon(
                            Icons.refresh,
                            size: 18,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            '새로고침',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildExistingCharacterPicker(),
                ] else ...[
                  _buildSectionTitle('2. 캐릭터에 대해 알려주세요!'),
                  const SizedBox(height: 16),
                  if (_selectedMethod == '랜덤 생성')
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(_rollRandomCharacter),
                        icon: const Icon(
                          Icons.casino,
                          size: 18,
                          color: AppTheme.yellowColor,
                        ),
                        label: const Text(
                          '🎲 다시 뽑기',
                          style: TextStyle(color: AppTheme.yellowColor),
                        ),
                      ),
                    ),
                  _buildCustomTextField(
                    controller: _nameController,
                    label: '캐릭터 이름',
                    hint: '예: 뽀로로, 토끼',
                  ),
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: _personalityController,
                    label: '성격 (예: Curious, Brave)',
                    hint: '용감하고 호기심이 많아요',
                  ),
                  const SizedBox(height: 16),
                  _buildCustomTextField(
                    controller: _descriptionController,
                    label: '캐릭터 설명',
                    hint: '빨간 모자를 쓰고 있고, 달리기를 아주 잘해요.',
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 40),

                // ==========================================
                // [SG02] 삽화 스타일 선택 영역
                // ==========================================
                _buildSectionTitle('3. 어떤 그림체로 볼까요?'),
                const SizedBox(height: 4),
                const Text(
                  '지금은 화면에서 골라 두는 것까지만 반영돼요. 실제 그림에 적용되는 건 곧 이어질 예정이에요!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStyleChip('아동풍'),
                    _buildStyleChip('리얼풍'),
                    _buildStyleChip('수채화풍'),
                    _buildStyleChip('3D 애니메이션'),
                  ],
                ),
                const SizedBox(height: 50),

                // ==========================================
                // 다음 단계 이동 버튼
                // ==========================================
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleNext,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '다음 단계로 (스토리 배경 설정)',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI 컴포넌트 분리 ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMethodCard(String method, IconData icon) {
    bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => _selectMethod(method),
      child: Container(
        height: 120, // 태블릿 화면 고려한 높이
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.yellowColor
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white30,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? AppTheme.navyColor : Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              method,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.navyColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 이미 만든 캐릭터를 고르는 가로 목록. (P-SG01 '기존 캐릭터 선택')
  ///
  /// 캐릭터 API가 소유권을 구분하지 않아(back#40 3번) 다른 사용자가 만든
  /// 캐릭터도 함께 보일 수 있다.
  Widget _buildExistingCharacterPicker() {
    return Consumer<CharacterProvider>(
      builder: (context, characters, _) {
        return SizedBox(
          height: 120,
          child: AsyncStateView(
            isLoading: characters.isLoading,
            errorMessage: characters.loadError,
            onRetry: characters.load,
            isEmpty: characters.isEmpty,
            emptyMessage: '아직 만든 캐릭터가 없어요.\n다른 방법으로 새로 만들어 보세요!',
            contentBuilder: (context) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: characters.characters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final character = characters.characters[index];
                final isSelected =
                    _selectedCharacterId == character.characterId;
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedCharacterId = character.characterId,
                  ),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.yellowColor
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white30,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.face,
                          size: 32,
                          color: isSelected ? AppTheme.navyColor : Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          character.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.navyColor
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.yellowColor, width: 2),
        ),
      ),
    );
  }

  // SG02: 이미지 스타일 선택 칩
  Widget _buildStyleChip(String style) {
    bool isSelected = _selectedStyle == style;
    return ChoiceChip(
      label: Text(
        style,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          // 선택되면 네이비 글씨, 선택 안 되면 흰색 글씨
          color: isSelected ? AppTheme.navyColor : Colors.white,
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) _selectedStyle = style;
        });
      },
      selectedColor: AppTheme.yellowColor,
      // 선택 시 노란색 배경
      backgroundColor: AppTheme.navyColor,
      // 선택 안 됐을 땐 네이비색 배경
      surfaceTintColor: Colors.transparent,
      // 플러터 기본 하얀색 오버레이 강제 제거
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          // 선택 안 됐을 때만 얇은 하얀색 테두리 표시
          color: isSelected ? Colors.transparent : Colors.white54,
          width: 1.5,
        ),
      ),
      showCheckmark: false,
    );
  }
}
