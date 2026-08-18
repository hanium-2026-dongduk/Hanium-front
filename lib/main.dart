import 'package:flutter/material.dart';
import 'theme/theme.dart';
import 'package:hanium_front/screens/story_creation_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magic Book',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,

      // ✨ 임시 테스트 코드를 지우고, 우리가 만든 스토리 생성 화면을 앱의 첫 화면으로 지정!
      home: const StoryCreationScreen(),
    );
  }
}
