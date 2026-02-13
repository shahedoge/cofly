/// 全局常量
class Constants {
  // Hive box names
  static const String kMessagesBox = 'messages';
  static const String kConfigBox = 'config';

  // SharedPreferences keys
  static const String kApiUrl = 'api_url';
  static const String kUsername = 'username';
  static const String kUserAvatar = 'user_avatar';
  static const String kBotAvatar = 'bot_avatar';
  static const String kBotName = 'bot_name';
  static const String kBotUsername = 'bot_username';
  static const String kThemeColor = 'theme_color';
  static const String kIsFirstLaunch = 'is_first_launch';

  // Secure storage keys
  static const String kPassword = 'password';

  // Message cache days
  static const int kMessageCacheDays = 2;

  // Default values
  static const String kDefaultApiUrl = '';
  static const String kDefaultBotName = 'Bot';
}
