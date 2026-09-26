import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 서버가 내려주는 `icon_key`(배지·스티커)를 앱 아이콘으로 바꾼다.
/// 서버에 이미지 파일이 없으므로 Material 아이콘으로 대신하고,
/// 모르는 키는 별 아이콘으로 떨어뜨린다.
class RewardIcons {
  RewardIcons._();

  static const Map<String, IconData> _icons = {
    // 배지
    'foot': Icons.pets,
    'calendar': Icons.calendar_month,
    'fire_small': Icons.local_fire_department,
    'fire': Icons.whatshot,
    'coin': Icons.monetization_on,
    'treasure': Icons.diamond,
    'sprout': Icons.spa,
    'check': Icons.task_alt,
    'book': Icons.menu_book,
    'brain': Icons.psychology,
    'pencil': Icons.edit,
    // 칭찬 스티커
    'thumbs_up': Icons.thumb_up,
    'star': Icons.star,
    'heart': Icons.favorite,
    'muscle': Icons.fitness_center,
    'clover': Icons.eco,
    'hug': Icons.volunteer_activism,
  };

  static const List<Color> _palette = [
    AppTheme.pastelGreen,
    AppTheme.pastelBlue,
    AppTheme.pastelPink,
    AppTheme.pastelPurple,
    AppTheme.yellowColor,
  ];

  static IconData iconFor(String? key) => _icons[key] ?? Icons.star;

  /// 같은 키는 항상 같은 색이 나오도록 키 문자열로 색을 고른다.
  static Color colorFor(String? key) {
    if (key == null || key.isEmpty) return AppTheme.yellowColor;
    return _palette[key.codeUnits.fold<int>(0, (sum, c) => sum + c) % _palette.length];
  }
}
