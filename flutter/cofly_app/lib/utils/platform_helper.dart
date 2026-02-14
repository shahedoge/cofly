import 'dart:io' show Platform;

class PlatformHelper {
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}
