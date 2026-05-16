import 'package:flutter/material.dart';

enum AppThemeType {
  purpleViolet,
  pinkCoral,
  greenTurquoise,
  orangeSunset,
  blueOcean,
  peachCream,
  monochrome,
  sunsetRedPurple,
  neonCyber,
  goldBronze,
  lightMode,
  darkMode,
}

class AppThemes {
  static ThemeData get(AppThemeType type) => _themes[type.index];

  static Gradient accentGradient(AppThemeType type) => _gradients[type.index];

  static const themeNames = [
    'パープルバイオレット 🟣',
    'ピンクコーラル 🌸',
    'グリーンターコイズ 🌿',
    'Orange Sunset 🌅',
    'Blue Ocean 🌊',
    'ピーチクリーム 🍑',
    'モノクローム ⚫️',
    'Sunset Red Purple 🌇',
    'Neon Cyber 💎',
    'ゴールドブロンズ 👑',
    'ライト ☀️',
    'ダーク 🌙',
  ];

  static const themeKeywords = [
    'クール、テック',
    '暖かさ、元気',
    'ヘルシー、爽やか',
    '活力、パワフル',
    '落ち着き、プロ',
    'やさしい、柔らかい',
    'シック、高級感',
    '夕焼け、情熱',
    'サイバーパンク、未来',
    'ラグジュアリー',
    'シンプル、明るい',
    'シンプル、落ち着き',
  ];

  static const accentColors = [
    Color(0xFF667eea),
    Color(0xFFf093fb),
    Color(0xFF43e97b),
    Color(0xFFfa709a),
    Color(0xFF30cfd0),
    Color(0xFFffd4c2),
    Color(0xFFd4d4d4),
    Color(0xFFff6b6b),
    Color(0xFF00f5ff),
    Color(0xFFf4d03f),
    Color(0xFF4285F4), // light
    Color(0xFF555555), // dark
  ];

  static final _gradients = <Gradient>[
    // A: Purple Violet
    const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // B: Pink Coral
    const LinearGradient(colors: [Color(0xFFf093fb), Color(0xFFf5576c)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // C: Green Turquoise
    const LinearGradient(colors: [Color(0xFF43e97b), Color(0xFF38f9d7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // D: Orange Sunset
    const LinearGradient(colors: [Color(0xFFfa709a), Color(0xFFfee140)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // E: Blue Ocean
    const LinearGradient(colors: [Color(0xFF30cfd0), Color(0xFF330867)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // F: Peach Cream
    const LinearGradient(colors: [Color(0xFFffecd2), Color(0xFFfcb69f)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // G: Monochrome
    const LinearGradient(colors: [Color(0xFFd4d4d4), Color(0xFF8a8a8a)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // H: Sunset Red Purple
    const LinearGradient(colors: [Color(0xFFff6b6b), Color(0xFFa855f7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // I: Neon Cyber
    const LinearGradient(colors: [Color(0xFF00f5ff), Color(0xFFff00ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // J: Gold Bronze
    const LinearGradient(colors: [Color(0xFFf4d03f), Color(0xFFc87941)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // K: Light
    const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    // L: Dark
    const LinearGradient(colors: [Color(0xFF555555), Color(0xFF222222)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  static final _themes = <ThemeData>[
    // A: Purple Violet
    _build(bg: const Color(0xFF1a1520), card: const Color(0xFF231d2e), primary: const Color(0xFF667eea), secondary: const Color(0xFF764ba2)),
    // B: Pink Coral
    _build(bg: const Color(0xFF2a1810), card: const Color(0xFF331f16), primary: const Color(0xFFf093fb), secondary: const Color(0xFFf5576c)),
    // C: Green Turquoise
    _build(bg: const Color(0xFF0f1f16), card: const Color(0xFF16271d), primary: const Color(0xFF43e97b), secondary: const Color(0xFF38f9d7)),
    // D: Orange Sunset
    _build(bg: const Color(0xFF2a1508), card: const Color(0xFF331b0e), primary: const Color(0xFFfa709a), secondary: const Color(0xFFfee140)),
    // E: Blue Ocean
    _build(bg: const Color(0xFF0f1620), card: const Color(0xFF161e2a), primary: const Color(0xFF30cfd0), secondary: const Color(0xFF5523a0)),
    // F: Peach Cream
    _build(bg: const Color(0xFF241a15), card: const Color(0xFF2d211b), primary: const Color(0xFFffd4c2), secondary: const Color(0xFFfcb69f)),
    // G: Monochrome
    _build(bg: const Color(0xFF1a1a1a), card: const Color(0xFF242424), primary: const Color(0xFFd4d4d4), secondary: const Color(0xFF8a8a8a)),
    // H: Sunset Red Purple
    _build(bg: const Color(0xFF250812), card: const Color(0xFF2e0e19), primary: const Color(0xFFff6b6b), secondary: const Color(0xFFa855f7)),
    // I: Neon Cyber
    _build(bg: const Color(0xFF0f0f1f), card: const Color(0xFF161626), primary: const Color(0xFF00f5ff), secondary: const Color(0xFFff00ff)),
    // J: Gold Bronze
    _build(bg: const Color(0xFF231c12), card: const Color(0xFF2c2318), primary: const Color(0xFFf4d03f), secondary: const Color(0xFFc87941)),
    // K: Light
    _buildLight(bg: const Color(0xFFF0F4F7), card: Colors.white, primary: const Color(0xFF4285F4), secondary: const Color(0xFF34A853)),
    // L: Dark
    _build(bg: const Color(0xFF111111), card: const Color(0xFF1E1E1E), primary: const Color(0xFF888888), secondary: const Color(0xFF555555)),
  ];

  static ThemeData _build({
    required Color bg,
    required Color card,
    required Color primary,
    required Color secondary,
  }) {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: card,
      ),
      scaffoldBackgroundColor: bg,
      cardColor: card,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primary,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData _buildLight({
    required Color bg,
    required Color card,
    required Color primary,
    required Color secondary,
  }) {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: card,
        onSurface: const Color(0xFF1a1a1a),
      ),
      scaffoldBackgroundColor: bg,
      cardColor: card,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1a1a1a),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1a1a1a)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primary,
      ),
      useMaterial3: true,
    );
  }
}
