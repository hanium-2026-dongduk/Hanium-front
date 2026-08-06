import 'package:flutter/material.dart';
import 'theme/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magic Book',
      theme: AppTheme.lightTheme, // theme.dart에서 정의한 테마 적용
      debugShowCheckedModeBanner: false, // 우측 상단 디버그(Debug) 띠 제거
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 영어 폰트(Quicksand) 테스트
              Text(
                'Hello, Magic Book!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // 네이비 배경에서 잘 보이도록 흰색 지정
                ),
              ),
              SizedBox(height: 20),
              // 한글 폰트(CookieRun) 테스트
              Text(
                '안녕, 꼬마 마법사!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.yellowColor, // 포인트 컬러인 노란색 지정
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
