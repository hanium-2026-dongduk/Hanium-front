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
      home: const StoryCreationScreen(), // 앱 시작점 변경
    );
  }
}
