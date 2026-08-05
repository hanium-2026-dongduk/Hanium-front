import 'package:flutter/material.dart';

class AppTheme {
  // 컬러 팔레트
  static const Color navyColor = Color(0xFF151628);
  static const Color yellowColor = Color(0xFFF4DC08);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: navyColor,
      scaffoldBackgroundColor: navyColor,

      // ✨ 앱 전체 기본 폰트를 쿠키런체로 완벽하게 통일!
      fontFamily: 'CookieRun',

      appBarTheme: const AppBarTheme(
        backgroundColor: navyColor,
        elevation: 0,
        centerTitle: true,
        // 앱바 제목 기본 스타일
        titleTextStyle: TextStyle(
          color: Colors.white, // 기본 글씨 하얀색
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'CookieRun', // 제목 쿠키런체로 고정
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellowColor,
          foregroundColor: navyColor,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold, // Bold 폰트 자동 적용
            fontFamily: 'CookieRun', // 버튼 텍스트도 확실하게 쿠키런체 적용
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}