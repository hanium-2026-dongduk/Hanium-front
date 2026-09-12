import 'package:flutter/material.dart';

class AppTheme {
  // 컬러 팔레트
  static const Color navyColor = Color(0xFF151628);
  static const Color yellowColor = Color(0xFFF4DC08);
  static const Color pastelGreen = Color(0xFFA5D6A7);
  static const Color pastelBlue = Color(0xFF90CAF9);
  static const Color pastelPink = Color(0xFFFFAB91);
  static const Color pastelPurple = Color(0xFFB39DDB);

  /// 영문 기본 폰트. 한글 글리프가 없어서 아래 대체 폰트가 받쳐줘야 한다.
  static const String _latinFont = 'Quicksand';

  /// Quicksand에 없는 한글을 그릴 폰트.
  static const List<String> _fallbackFonts = ['CookieRun'];

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: navyColor,
      scaffoldBackgroundColor: navyColor,

      // ✨ 폰트 매직 시작 ✨
      // 영문 기본 폰트로 Quicksand 지정
      fontFamily: _latinFont,
      // Quicksand에 없는 한글은 쿠키런체로 렌더링되도록 Fallback(대체) 지정
      fontFamilyFallback: _fallbackFonts,

      appBarTheme: const AppBarTheme(
        backgroundColor: navyColor,
        elevation: 0,
        centerTitle: true,
        // 지정하지 않으면 Material 3 기본값(거의 검정)이 잡혀서 네이비 배경 위에서
        // 제목이 보이지 않는다.
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: _latinFont,
          fontFamilyFallback: _fallbackFonts,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellowColor,
          foregroundColor: navyColor,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold, // Bold 폰트 자동 적용
            // 버튼 textStyle은 ThemeData의 fontFamily/fallback을 물려받지 못해서,
            // 여기서 다시 지정하지 않으면 한글이 시스템 폰트로 떨어진다.
            fontFamily: _latinFont,
            fontFamilyFallback: _fallbackFonts,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
