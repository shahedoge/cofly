import 'dart:io' show Platform;

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/platform_helper.dart';

/// 系统托盘服务（单例）
class TrayService with TrayListener {
  TrayService._();
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;

  bool _initialized = false;

  Future<void> init() async {
    if (!PlatformHelper.isDesktop) return;
    if (_initialized) return;

    // 根据平台设置托盘图标
    if (Platform.isWindows) {
      // Windows 使用 .ico 格式图标
      await trayManager.setIcon('assets/tray_icon.ico');
    } else if (Platform.isMacOS) {
      // macOS 使用模板图片
      await trayManager.setIcon(
        'assets/tray_icon.png',
        isTemplate: true,
      );
    }
    await trayManager.setToolTip('沙河小狗');

    final menu = Menu(items: [
      MenuItem(key: 'show_hide', label: '显示 / 隐藏窗口'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出 Cofly'),
    ]);
    await trayManager.setContextMenu(menu);

    trayManager.addListener(this);
    _initialized = true;
  }

  @override
  void onTrayIconMouseDown() async {
    // Left click toggles window visibility
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_hide':
        onTrayIconMouseDown();
        break;
      case 'quit':
        await windowManager.setPreventClose(false);
        await windowManager.close();
        break;
    }
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
