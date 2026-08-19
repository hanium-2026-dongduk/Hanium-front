import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/screens/story_setting_screen.dart';
import 'package:hanium_front/models/story_payload.dart';

class StoryCreationScreen extends StatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  State<StoryCreationScreen> createState() => _StoryCreationScreenState();
}

class _StoryCreationScreenState extends State<StoryCreationScreen> {
  // --- [SG01] 동화 생성 상태 변수 ---
  String _selectedMethod = '기존 캐릭터 선택';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personalityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // --- [SG02] 삽화 생성 상태 변수 ---
  String _selectedStyle = '아동풍';

  @override
  void dispose() {
    _nameController.dispose();
    _personalityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('✨ 새로운 동화 만들기')),
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
                // [SG01] 캐릭터 세부 정보 입력 영역
                // ==========================================
                _buildSectionTitle('2. 캐릭터에 대해 알려주세요!'),
                const SizedBox(height: 16),
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
                const SizedBox(height: 40),

                // ==========================================
                // [SG02] 삽화 스타일 선택 영역
                // ==========================================
                _buildSectionTitle('3. 어떤 그림체로 볼까요?'),
                const SizedBox(height: 16),
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
                    onPressed: () {
                      // 이름 칸이 비어있는지 확인하는 유효성 검사
                      if (_nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('캐릭터 이름을 입력해 주세요!')),
                        );
                        return; // 값이 비어있다면 로직 멈추고 화면 이동 막음
                      }

                      // ✨ 1. 빈 택배 상자(DTO)를 하나 만들고, 지금까지 입력한 데이터를 담기
                      final payload = StoryCreatePayload(
                        characterMethod: _selectedMethod,
                        characterName: _nameController.text,
                        characterPersonality: _personalityController.text,
                        characterDescription: _descriptionController.text,
                        imageStyle: _selectedStyle,
                      );

                      // ✨ 2. 상자를 들고 다음 화면으로 이동!
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StorySettingScreen(payload: payload),
                        ),
                      );
                    },
                    child: const Text(
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
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
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
