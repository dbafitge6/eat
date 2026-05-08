import 'package:flutter/material.dart';

enum AppThemeType { dark, light, green }

class AppThemes {
  static ThemeData get(AppThemeType type) {
    switch (type) {
      case AppThemeType.dark:
        return _dark;
      case AppThemeType.light:
        return _light;
      case AppThemeType.green:
        return _green;
    }
  }

  static final _dark = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E5FF),
      secondary: Color(0xFF69F0AE),
      surface: Color(0xFF1E1E1E),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Color(0xFF00E5FF),
      unselectedItemColor: Colors.grey,
    ),
    useMaterial3: true,
  );

  static final _light = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2196F3),
      secondary: Color(0xFFFF9800),
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF212121),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Color(0xFF212121)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF2196F3),
      unselectedItemColor: Colors.grey,
    ),
    useMaterial3: true,
  );

  static final _green = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4CAF50),
      secondary: Color(0xFF8BC34A),
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF1F8E9),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF4CAF50),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF4CAF50),
      unselectedItemColor: Colors.grey,
    ),
    useMaterial3: true,
  );

  static const themeNames = ['A: ダーク', 'B: ライト', 'C: グリーン'];
}
