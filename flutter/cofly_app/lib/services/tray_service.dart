import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 系统托盘服务（单例）
class TrayService with TrayListener {
  TrayService._();
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // tray_manager on macOS loads the icon via rootBundle.load(),
    // so pass the Flutter asset path directly.
    await trayManager.setIcon(
      'assets/tray_icon.png',
      isTemplate: true,
    );
    await trayManager.setToolTip('Cofly');

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
