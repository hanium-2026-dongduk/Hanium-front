import 'package:flutter/material.dart';

class AppTheme {
  static const Color navyColor = Color(0xFF151628);
  static const Color yellowColor = Color(0xFFF4DC08);
  static const Color pastelGreen = Color(0xFFA5D6A7);
  static const Color pastelBlue = Color(0xFF90CAF9);
  static const Color pastelPink = Color(0xFFFFAB91);
  static const Color pastelPurple = Color(0xFFB39DDB);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: navyColor,
      scaffoldBackgroundColor: navyColor,
      fontFamily: 'CookieRun',
      appBarTheme: const AppBarTheme(
        backgroundColor: navyColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'CookieRun',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellowColor,
          foregroundColor: navyColor,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'CookieRun',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
