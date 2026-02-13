import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/config.dart';
import '../models/message.dart';
import '../utils/constants.dart';

/// 本地存储服务
class StorageService {
  // Singleton
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Storage instances
  late SharedPreferences _prefs;
  late Box _messagesBox;
  late Box _configBox;

  // Initialization
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();

    // Initialize Hive with Application Support directory
    final appDir = await getApplicationSupportDirectory();
    final hivePath = '${appDir.path}/cofly_data';
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);

    // Open Hive boxes
    _messagesBox = await Hive.openBox(
      Constants.kMessagesBox,
    );
    _configBox = await Hive.openBox(
      Constants.kConfigBox,
    );

    _isInitialized = true;
  }

  // ==================== Config Operations ====================

  /// 保存 API URL
  Future<void> setApiUrl(String url) async {
    await _prefs.setString(Constants.kApiUrl, url);
    await _saveConfigToHive();
  }

  /// 获取 API URL
  String getApiUrl() {
    return _prefs.getString(Constants.kApiUrl) ?? Constants.kDefaultApiUrl;
  }

  /// 保存用户名
  Future<void> setUsername(String username) async {
    await _prefs.setString(Constants.kUsername, username);
    await _saveConfigToHive();
  }

  /// 获取用户名
  String? getUsername() {
    return _prefs.getString(Constants.kUsername);
  }

  /// 保存密码
  Future<void> setPassword(String password) async {
    await _prefs.setString(Constants.kPassword, password);
    await _saveConfigToHive();
  }

  /// 获取密码
  Future<String?> getPassword() async {
    return _prefs.getString(Constants.kPassword);
  }

  /// 保存用户头像
  Future<void> setUserAvatar(String? avatar) async {
    await _prefs.setString(Constants.kUserAvatar, avatar ?? '');
    await _saveConfigToHive();
  }

  /// 获取用户头像
  String? getUserAvatar() {
    final avatar = _prefs.getString(Constants.kUserAvatar);
    return avatar?.isNotEmpty == true ? avatar : null;
  }

  /// 保存 Bot 头像
  Future<void> setBotAvatar(String? avatar) async {
    await _prefs.setString(Constants.kBotAvatar, avatar ?? '');
    await _saveConfigToHive();
  }

  /// 获取 Bot 头像
  String? getBotAvatar() {
    final avatar = _prefs.getString(Constants.kBotAvatar);
    return avatar?.isNotEmpty == true ? avatar : null;
  }

  /// 保存 Bot 唯一标识符
  Future<void> setBotUsername(String? username) async {
    await _prefs.setString(Constants.kBotUsername, username ?? '');
    await _saveConfigToHive();
  }

  /// 获取 Bot 唯一标识符
  String? getBotUsername() {
    final username = _prefs.getString(Constants.kBotUsername);
    return username?.isNotEmpty == true ? username : null;
  }

  /// 保存 Bot 名称
  Future<void> setBotName(String? name) async {
    await _prefs.setString(Constants.kBotName, name ?? '');
    await _saveConfigToHive();
  }

  /// 获取 Bot 名称
  String? getBotName() {
    final name = _prefs.getString(Constants.kBotName);
    return name?.isNotEmpty == true ? name : null;
  }

  /// 保存主题色
  Future<void> setThemeColor(Color? color) async {
    await _prefs.setInt(Constants.kThemeColor, color?.value ?? 0);
    await _saveConfigToHive();
  }

  /// 获取主题色
  Color? getThemeColor() {
    final value = _prefs.getInt(Constants.kThemeColor);
    return value != null && value != 0 ? Color(value) : null;
  }

  /// 设置深色模式
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool('is_dark_mode', isDark);
    await _saveConfigToHive();
  }

  /// 获取深色模式
  bool isDarkMode() {
    return _prefs.getBool('is_dark_mode') ?? false;
  }

  /// 设置首次启动
  Future<void> setFirstLaunch(bool isFirst) async {
    await _prefs.setBool(Constants.kIsFirstLaunch, isFirst);
  }

  /// 是否首次启动
  bool isFirstLaunch() {
    return _prefs.getBool(Constants.kIsFirstLaunch) ?? true;
  }

  // ==================== Message Operations ====================

  /// 保存消息到本地
  Future<void> saveMessage(Message message) async {
    final dateKey = _getDateKey(message.chatId, message.createdAt);
    final messages = await getMessagesByDate(message.chatId, message.createdAt);

    // Upsert: 替换已有消息或追加新消息
    final idx = messages.indexWhere((m) => m.id == message.id);
    if (idx >= 0) {
      messages[idx] = message;
    } else {
      messages.add(message);
    }
    await _messagesBox.put(dateKey, {
      'messages': messages.map((m) => m.toHiveJson()).toList(),
    });
  }

  /// 按日期获取消息
  Future<List<Message>> getMessagesByDate(String chatId, DateTime date) async {
    final dateKey = _getDateKey(chatId, date);
    final raw = _messagesBox.get(dateKey);

    if (raw == null) return [];

    final data = Map<String, dynamic>.from(raw as Map);
    final messages = (data['messages'] as List<dynamic>)
        .map((e) => Message.fromHiveJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return messages;
  }

  /// 获取最近几天的消息
  Future<List<Message>> getRecentMessages(
    String chatId, {
    int days = 2,
  }) async {
    final allMessages = <Message>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final messages = await getMessagesByDate(chatId, date);
      allMessages.addAll(messages);
    }

    // 按时间排序
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allMessages;
  }

  /// 清除指定日期之前的消息
  Future<void> clearOldMessages(String chatId, {int daysKeep = 2}) async {
    final now = DateTime.now();
    final keysToDelete = <String>[];

    // 遍历所有消息 key
    for (final key in _messagesBox.keys) {
      if (key is String && key.startsWith('${chatId}_')) {
        final dateStr = key.substring(key.lastIndexOf('_') + 1);
        try {
          final date = DateTime.parse(dateStr);
          final diff = now.difference(date).inDays;
          if (diff > daysKeep) {
            keysToDelete.add(key);
          }
        } catch (e) {
          // 忽略解析错误的 key
        }
      }
    }

    // 删除过期消息
    for (final key in keysToDelete) {
      await _messagesBox.delete(key);
    }
  }

  /// 清除所有聊天记录
  Future<void> clearAllMessages() async {
    await _messagesBox.clear();
  }

  /// 删除单条消息
  Future<void> deleteMessage(Message message) async {
    final dateKey = _getDateKey(message.chatId, message.createdAt);
    final messages = await getMessagesByDate(message.chatId, message.createdAt);
    messages.removeWhere((m) => m.id == message.id);
    if (messages.isEmpty) {
      await _messagesBox.delete(dateKey);
    } else {
      await _messagesBox.put(dateKey, {
        'messages': messages.map((m) => m.toHiveJson()).toList(),
      });
    }
  }

  /// 根据关键词搜索消息
  Future<List<Message>> searchMessages(
    String chatId,
    String keyword,
  ) async {
    final allMessages = await getRecentMessages(chatId, days: 30);
    final lowerKeyword = keyword.toLowerCase();

    return allMessages
        .where((m) => m.content.toLowerCase().contains(lowerKeyword))
        .toList();
  }

  // ==================== Config Model Operations ====================

  /// 加载完整配置
  Future<AppConfig> loadConfig() async {
    final raw = _configBox.get('app_config');

    if (raw != null) {
      return AppConfig.fromHiveJson(Map<String, dynamic>.from(raw as Map));
    }

    // 从各个存储位置加载
    return AppConfig(
      apiUrl: getApiUrl(),
      username: getUsername(),
      userAvatar: getUserAvatar(),
      botAvatar: getBotAvatar(),
      botName: getBotName(),
      botUsername: getBotUsername(),
      themeColor: getThemeColor(),
      isDarkMode: isDarkMode(),
      isFirstLaunch: isFirstLaunch(),
    );
  }

  /// 保存完整配置到 Hive
  Future<void> _saveConfigToHive() async {
    final config = AppConfig(
      apiUrl: getApiUrl(),
      username: getUsername(),
      userAvatar: getUserAvatar(),
      botAvatar: getBotAvatar(),
      botName: getBotName(),
      botUsername: getBotUsername(),
      themeColor: getThemeColor(),
      isDarkMode: isDarkMode(),
      isFirstLaunch: isFirstLaunch(),
    );

    await _configBox.put('app_config', config.toHiveJson());
  }

  /// 清除所有本地数据 (退出登录)
  Future<void> clearAllData() async {
    // 清除配置
    await _prefs.clear();
    await _messagesBox.clear();
    await _configBox.clear();
  }

  // ==================== Helper Methods ====================

  /// 生成日期 key: {chatId}_{yyyyMMdd}
  String _getDateKey(String chatId, DateTime date) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '${chatId}_$dateStr';
  }
}
