import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../components/menu_button.dart';
import 'steps/step_api_url.dart';
import 'steps/step_auth.dart';
import 'steps/step_bot_avatar.dart';
import 'steps/step_bot_username.dart';
import 'steps/step_bot_name.dart';
import 'steps/step_user_avatar.dart';

/// 引导页步骤
enum OnboardingStep {
  apiUrl,
  auth,
  userAvatar,
  botAvatar,
  botUsername,
  botName,
}

/// 初始化引导页面
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  OnboardingStep _currentStep = OnboardingStep.apiUrl;
  final PageController _pageController = PageController();

  // 表单数据
  String _apiUrl = '';
  String _username = '';
  String _password = '';
  String _userAvatar = '';
  String _botAvatar = '';
  String _botUsername = '';
  String _botName = '';

  // 状态
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ==================== Navigation ====================

  void _nextStep() {
    if (_currentStep.index < OnboardingStep.values.length - 1) {
      setState(() {
        _currentStep = OnboardingStep.values[_currentStep.index + 1];
      });
      _pageController.animateToPage(
        _currentStep.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep.index > 0) {
      setState(() {
        _currentStep = OnboardingStep.values[_currentStep.index - 1];
      });
      _pageController.animateToPage(
        _currentStep.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToStep(OnboardingStep step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.jumpToPage(step.index);
  }

  // ==================== Data Handlers ====================

  void _onApiUrlSubmitted(String url) async {
    if (url.isNotEmpty) {
      _apiUrl = url;
      // 保存 API URL 到本地存储
      final storage = StorageService();
      await storage.init();
      await storage.setApiUrl(url);
      _nextStep();
    }
  }

  void _onAuthCompleted({
    required String username,
    required String password,
  }) {
    _username = username;
    _password = password;
    _nextStep();
  }

  void _onUserAvatarSelected(String? avatar) {
    _userAvatar = avatar ?? '';
    _nextStep();
  }

  void _onBotAvatarSelected(String? avatar) {
    _botAvatar = avatar ?? '';
    _nextStep();
  }

  void _onBotUsernameSubmitted(String username) {
    _botUsername = username;
    _nextStep();
  }

  void _onBotNameSubmitted(String name) {
    _botName = name;
    _completeOnboarding();
  }

  // ==================== Completion ====================

  Future<void> _completeOnboarding() async {
    // 保存所有配置到本地存储
    final storage = StorageService();
    await storage.init();

    await storage.setApiUrl(_apiUrl);
    await storage.setUsername(_username);
    await storage.setPassword(_password);
    await storage.setUserAvatar(_userAvatar.isEmpty ? null : _userAvatar);
    await storage.setBotAvatar(_botAvatar.isEmpty ? null : _botAvatar);
    await storage.setBotUsername(_botUsername.isEmpty ? null : _botUsername);
    await storage.setBotName(_botName.isEmpty ? null : _botName);
    await storage.setFirstLaunch(false);

    // 跳转到聊天页面
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/chat');
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final totalSteps = OnboardingStep.values.length;
    final currentIndex = _currentStep.index;

    return Scaffold(
      appBar: AppBar(
        leading: currentIndex > 0
            ? AppBackButton(
                onPressed: _previousStep,
              )
            : null,
        title: Text('设置 ($currentIndex/$totalSteps)'),
        actions: [
          // 跳过按钮 (仅在前几步显示)
          if (_currentStep != OnboardingStep.botName)
            TextButton(
              onPressed: () {
                switch (_currentStep) {
                  case OnboardingStep.userAvatar:
                    _onUserAvatarSelected(null);
                    break;
                  case OnboardingStep.botAvatar:
                    _onBotAvatarSelected(null);
                    break;
                  default:
                    break;
                }
              },
              child: const Text('跳过'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 进度指示器
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(
                totalSteps,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      left: index > 0 ? 4 : 0,
                      right: index < totalSteps - 1 ? 4 : 0,
                    ),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= currentIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 页面视图
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StepApiUrl(
                  initialUrl: _apiUrl,
                  onSubmitted: _onApiUrlSubmitted,
                ),
                StepAuth(
                  username: _username,
                  onCompleted: _onAuthCompleted,
                ),
                StepUserAvatar(
                  initialAvatar: _userAvatar,
                  onSelected: _onUserAvatarSelected,
                ),
                StepBotAvatar(
                  initialAvatar: _botAvatar,
                  onSelected: _onBotAvatarSelected,
                ),
                StepBotUsername(
                  initialUsername: _botUsername,
                  onSubmitted: _onBotUsernameSubmitted,
                ),
                StepBotName(
                  initialName: _botName,
                  onSubmitted: _onBotNameSubmitted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 引导页路由
class OnboardingRoute extends MaterialPageRoute {
  OnboardingRoute()
      : super(
          builder: (context) => const OnboardingPage(),
        );
}
