import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../config/theme.dart';
import '../services/storage_service.dart';

/// 主题提供者
class ThemeProvider with ChangeNotifier {
  final StorageService _storage = StorageService();

  // State
  ThemeMode _themeMode = ThemeMode.system;
  Color? _seedColor;
  bool _useDynamicColors = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color? get seedColor => _seedColor;
  bool get useDynamicColors => _useDynamicColors;

  // ==================== Theme Management ====================

  /// 初始化主题
  Future<void> init() async {
    await _storage.init();

    // 加载保存的主题设置
    final isDarkMode = _storage.isDarkMode();
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

    _seedColor = _storage.getThemeColor();
    _useDynamicColors = _seedColor == null;

    notifyListeners();
  }

  /// 获取当前主题数据
  ThemeData getThemeData() {
    if (_useDynamicColors) {
      return _getDynamicTheme();
    } else {
      return _seedColor != null
          ? AppTheme.lightTheme(_seedColor)
          : AppTheme.lightTheme(null);
    }
  }

  /// 获取动态主题
  ThemeData _getDynamicTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor ?? Colors.blue,
      ),
    );
  }

  /// 获取亮度
  Brightness _getBrightness() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.setDarkMode(mode == ThemeMode.dark);
    notifyListeners();
  }

  /// 切换深色模式
  Future<void> toggleDarkMode() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _storage.setDarkMode(_themeMode == ThemeMode.dark);
    notifyListeners();
  }

  /// 设置主题色
  Future<void> setThemeColor(Color? color) async {
    if (color != null) {
      _useDynamicColors = false;
      _seedColor = color;
      await _storage.setThemeColor(color);
    } else {
      _useDynamicColors = true;
      _seedColor = null;
      await _storage.setThemeColor(null);
    }
    notifyListeners();
  }

  /// 使用系统动态颜色
  Future<void> useSystemDynamicColors() async {
    _useDynamicColors = true;
    _seedColor = null;
    await _storage.setThemeColor(null);
    notifyListeners();
  }

  /// 获取预设颜色列表
  List<Color> getPresetColors() {
    return AppTheme.presetColors;
  }

  /// 获取当前颜色方案
  ColorScheme getColorScheme() {
    return getThemeData().colorScheme;
  }

  /// 是否为深色模式
  bool isDarkMode() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && brightness == Brightness.dark);
  }
}
