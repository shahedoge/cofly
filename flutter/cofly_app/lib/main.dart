import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/chat/chat_page.dart';
import 'screens/onboarding/onboarding_page.dart';
import 'screens/settings/settings_page.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/tray_service.dart';
import 'utils/platform_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (PlatformHelper.isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await TrayService().init();
  }
  await NotificationService().init();
  runApp(const CoflyApp());
}

class CoflyApp extends StatefulWidget {
  const CoflyApp({super.key});

  @override
  State<CoflyApp> createState() => _CoflyAppState();
}

class _CoflyAppState extends State<CoflyApp> with WindowListener {
  late final ThemeProvider _themeProvider;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    if (PlatformHelper.isDesktop) {
      windowManager.addListener(this);
    }
    _themeProvider = ThemeProvider();
    _authProvider = AuthProvider();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _themeProvider.init();
    await _authProvider.checkAuthStatus();
  }

  @override
  void onWindowClose() async {
    if (PlatformHelper.isDesktop) {
      // Hide instead of quit
      await windowManager.hide();
    }
  }

  @override
  void dispose() {
    if (PlatformHelper.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Cofly',
            theme: themeProvider.getThemeData(),
            darkTheme: AppTheme.darkTheme(themeProvider.seedColor),
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            routes: {
              '/': (context) => const SplashPage(),
              '/onboarding': (context) => const OnboardingPage(),
              '/chat': (context) => const ChatPage(),
              '/settings': (context) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
}

/// 启动页面
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToNextPage();
  }

  Future<void> _navigateToNextPage() async {
    final authProvider = context.read<AuthProvider>();
    await Future.delayed(const Duration(milliseconds: 500));

    // 检查是否首次启动
    final storage = StorageService();
    await storage.init();

    if (storage.isFirstLaunch()) {
      // 首次启动，跳转到引导页
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } else if (authProvider.isAuthenticated) {
      // 已登录，跳转到聊天页
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/chat');
      }
    } else {
      // 未登录但不是首次启动，检查登录状态
      await authProvider.checkAuthStatus();

      if (mounted) {
        if (authProvider.isAuthenticated) {
          Navigator.of(context).pushReplacementNamed('/chat');
        } else {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 80, height: 80),
            const SizedBox(height: 16),
            const Text(
              'Cofly',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '智能聊天助手',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
