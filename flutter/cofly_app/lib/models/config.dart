import 'dart:convert';
import 'dart:ui';

/// 应用配置模型
class AppConfig {
  String apiUrl;
  String? username;
  String? password;
  String? userAvatar;
  String? botAvatar;
  String? botName;
  String? botUsername;
  Color? themeColor;
  bool isDarkMode;
  bool isFirstLaunch;

  AppConfig({
    required this.apiUrl,
    this.username,
    this.password,
    this.userAvatar,
    this.botAvatar,
    this.botName,
    this.botUsername,
    this.themeColor,
    this.isDarkMode = false,
    this.isFirstLaunch = true,
  });

  /// 获取 Bot 头像，如果没有设置则返回默认头像
  String get effectiveBotAvatar {
    return botAvatar?.isNotEmpty == true
        ? botAvatar!
        : 'https://ui-avatars.com/api/?name=Bot&background=random';
  }

  /// 获取用户头像，如果没有设置则返回默认头像
  String get effectiveUserAvatar {
    return userAvatar?.isNotEmpty == true
        ? userAvatar!
        : 'https://ui-avatars.com/api/?name=User&background=random';
  }

  /// 获取 Bot 名称，如果没有设置则返回默认名称
  String get effectiveBotName {
    return botName?.isNotEmpty == true ? botName! : 'Bot';
  }

  /// 检查是否已配置
  bool get isConfigured {
    return apiUrl.isNotEmpty &&
        username != null &&
        username!.isNotEmpty &&
        password != null &&
        password!.isNotEmpty;
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'api_url': apiUrl,
      'username': username,
      'password': password,
      'user_avatar': userAvatar,
      'bot_avatar': botAvatar,
      'bot_name': botName,
      'bot_username': botUsername,
      'theme_color': themeColor?.value,
      'is_dark_mode': isDarkMode,
      'is_first_launch': isFirstLaunch,
    };
  }

  /// 从 JSON 创建配置
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      apiUrl: json['api_url'] ?? '',
      username: json['username'],
      password: json['password'],
      userAvatar: json['user_avatar'],
      botAvatar: json['bot_avatar'],
      botName: json['bot_name'],
      botUsername: json['bot_username'],
      themeColor: json['theme_color'] != null
          ? Color(json['theme_color'] as int)
          : null,
      isDarkMode: json['is_dark_mode'] ?? false,
      isFirstLaunch: json['is_first_launch'] ?? true,
    );
  }

  /// 转换为 Hive 存储格式
  Map<String, dynamic> toHiveJson() {
    return {
      'apiUrl': apiUrl,
      'username': username,
      'password': password,
      'userAvatar': userAvatar,
      'botAvatar': botAvatar,
      'botName': botName,
      'botUsername': botUsername,
      'themeColor': themeColor?.value,
      'isDarkMode': isDarkMode,
      'isFirstLaunch': isFirstLaunch,
    };
  }

  /// 从 Hive 格式创建配置
  factory AppConfig.fromHiveJson(Map<String, dynamic> json) {
    return AppConfig(
      apiUrl: json['apiUrl'] ?? '',
      username: json['username'],
      password: json['password'],
      userAvatar: json['userAvatar'],
      botAvatar: json['botAvatar'],
      botName: json['botName'],
      botUsername: json['botUsername'],
      themeColor: json['themeColor'] != null
          ? Color(json['themeColor'] as int)
          : null,
      isDarkMode: json['isDarkMode'] ?? false,
      isFirstLaunch: json['isFirstLaunch'] ?? true,
    );
  }

  /// 复制配置并修改部分字段
  AppConfig copyWith({
    String? apiUrl,
    String? username,
    String? password,
    String? userAvatar,
    String? botAvatar,
    String? botName,
    String? botUsername,
    Color? themeColor,
    bool? isDarkMode,
    bool? isFirstLaunch,
  }) {
    return AppConfig(
      apiUrl: apiUrl ?? this.apiUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      userAvatar: userAvatar ?? this.userAvatar,
      botAvatar: botAvatar ?? this.botAvatar,
      botName: botName ?? this.botName,
      botUsername: botUsername ?? this.botUsername,
      themeColor: themeColor ?? this.themeColor,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
    );
  }

  @override
  String toString() {
    return 'AppConfig(apiUrl: $apiUrl, username: $username, botName: $botName)';
  }
}
