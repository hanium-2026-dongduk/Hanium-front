import 'package:flutter/material.dart';
import 'package:hanium_front/theme/theme.dart';
import 'story_keyword_screen.dart';
import 'package:hanium_front/models/story_payload.dart';

/// '직접 입력'을 골랐다는 표시. 실제 값은 별도 컨트롤러에 있다.
const _customOption = '직접 입력';

class StorySettingScreen extends StatefulWidget {
  final StoryCreatePayload payload;

  const StorySettingScreen({super.key, required this.payload});

  @override
  State<StorySettingScreen> createState() => _StorySettingScreenState();
}

class _StorySettingScreenState extends State<StorySettingScreen> {
  String _selectedLocation = '';
  String _selectedEvent = '';
  bool _isCustomLocation = false;
  bool _isCustomEvent = false;
  final _customLocationController = TextEditingController();
  final _customEventController = TextEditingController();

  @override
  void dispose() {
    _customLocationController.dispose();
    _customEventController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STEP 1: 주제 고르기')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('어디에서 일어날까요?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCircleSelectBtn('신비로운 숲', Icons.park, true),
                    _buildCircleSelectBtn('바다 깊은 곳', Icons.water, true),
                    _buildCircleSelectBtn('하늘 위 성', Icons.cloud, true),
                    _buildCircleSelectBtn(
                      _customOption,
                      Icons.edit_outlined,
                      true,
                    ),
                  ],
                ),
                if (_isCustomLocation) ...[
                  const SizedBox(height: 16),
                  _buildCustomField(
                    controller: _customLocationController,
                    hint: '예: 별들이 춤추는 밤하늘',
                    onChanged: (value) =>
                        setState(() => _selectedLocation = value),
                  ),
                ],
                const SizedBox(height: 40),

                _buildSectionTitle('어떤 일이 일어날까요?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCircleSelectBtn('숨겨진 보물 찾기', Icons.diamond, false),
                    _buildCircleSelectBtn('마법사 물리치기', Icons.flash_on, false),
                    _buildCircleSelectBtn('친구 구하기', Icons.people, false),
                    _buildCircleSelectBtn(
                      _customOption,
                      Icons.edit_outlined,
                      false,
                    ),
                  ],
                ),
                if (_isCustomEvent) ...[
                  const SizedBox(height: 16),
                  _buildCustomField(
                    controller: _customEventController,
                    hint: '예: 잃어버린 목소리를 되찾는다',
                    onChanged: (value) =>
                        setState(() => _selectedEvent = value),
                  ),
                ],
                const SizedBox(height: 60),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedLocation.trim().isEmpty ||
                          _selectedEvent.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('배경과 사건을 하나씩 골라 주세요!')),
                        );
                        return;
                      }

                      widget.payload.location = _selectedLocation.trim();
                      widget.payload.event = _selectedEvent.trim();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StoryKeywordScreen(payload: widget.payload),
                        ),
                      );
                    },
                    child: const Text(
                      '다음',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLength: 50,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        counterStyle: const TextStyle(color: Colors.white38),
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

  Widget _buildCircleSelectBtn(String label, IconData icon, bool isLocation) {
    final isCustom = label == _customOption;
    bool isSelected = isLocation
        ? (isCustom
              ? _isCustomLocation
              : (!_isCustomLocation && _selectedLocation == label))
        : (isCustom
              ? _isCustomEvent
              : (!_isCustomEvent && _selectedEvent == label));

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isLocation) {
            _isCustomLocation = isCustom;
            _selectedLocation = isCustom
                ? _customLocationController.text
                : label;
          } else {
            _isCustomEvent = isCustom;
            _selectedEvent = isCustom ? _customEventController.text : label;
          }
        });
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: isSelected
                ? AppTheme.yellowColor
                : Colors.white.withOpacity(0.1),
            child: Icon(
              icon,
              size: 36,
              color: isSelected ? AppTheme.navyColor : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.yellowColor : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
