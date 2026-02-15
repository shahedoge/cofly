import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  // 获取平台默认字体
  static String? _getDefaultFontFamily() {
    if (Platform.isWindows) {
      return 'Microsoft YaHei'; // Windows 微软雅黑，支持中文
    }
    return null; // 其他平台使用默认
  }

  // 浅色主题
  static ThemeData lightTheme(Color? seedColor) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _getDefaultFontFamily(),
      colorScheme: seedColor != null
          ? ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
            )
          : ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: seedColor ?? Colors.blue,
            width: 2,
          ),
        ),
      ),
    );
  }

  // 深色主题
  static ThemeData darkTheme(Color? seedColor) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _getDefaultFontFamily(),
      colorScheme: seedColor != null
          ? ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            )
          : ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: seedColor ?? Colors.blue,
            width: 2,
          ),
        ),
      ),
    );
  }

  // 预设主题色
  static const List<Color> presetColors = [
    Colors.blue,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.pink,
    Colors.red,
    Colors.cyan,
  ];

  // 默认头像
  static const String kDefaultUserAvatar =
      'https://ui-avatars.com/api/?name=User&background=random';
  static const String kDefaultBotAvatar =
      'https://ui-avatars.com/api/?name=Bot&background=random';
}
