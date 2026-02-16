import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../components/avatar.dart';
import '../components/menu_button.dart';
import 'about_page.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AuthProvider _authProvider;
  late final ThemeProvider _themeProvider;
  late final ChatProvider _chatProvider;
  late final StorageService _storage;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // 编辑状态
  bool _isEditingApiUrl = false;
  final TextEditingController _apiUrlController = TextEditingController();

  bool _isEditingPassword = false;
  final TextEditingController _passwordController = TextEditingController();

  bool _isEditingBotName = false;
  final TextEditingController _botNameController = TextEditingController();

  bool _isEditingBotUsername = false;
  final TextEditingController _botUsernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _themeProvider = context.read<ThemeProvider>();
    _chatProvider = context.read<ChatProvider>();
    _storage = StorageService();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _storage.init();

    _apiUrlController.text = _storage.getApiUrl();
    _botNameController.text = _storage.getBotName() ?? '';
    _botUsernameController.text = _storage.getBotUsername() ?? '';
  }

  Future<void> _pickUserAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final appDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(appDir.path, 'avatars'));
        if (!avatarDir.existsSync()) {
          avatarDir.createSync(recursive: true);
        }
        final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
        final destPath = p.join(avatarDir.path, 'user_avatar$ext');
        await File(image.path).copy(destPath);

        await _storage.setUserAvatar(destPath);
        await _authProvider.updateUser(avatar: destPath);
        setState(() {});
      }
    } catch (e) {
      _showError('选择头像失败');
    }
  }

  Future<void> _pickBotAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final appDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(appDir.path, 'avatars'));
        if (!avatarDir.existsSync()) {
          avatarDir.createSync(recursive: true);
        }
        final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
        final destPath = p.join(avatarDir.path, 'bot_avatar$ext');
        await File(image.path).copy(destPath);

        await _storage.setBotAvatar(destPath);
        await _authProvider.updateBotConfig(avatar: destPath);
        setState(() {});
      }
    } catch (e) {
      _showError('选择头像失败');
    }
  }

  Future<void> _updateApiUrl() async {
    final url = _apiUrlController.text.trim();
    if (url.isEmpty) {
      _showError('请输入 API 地址');
      return;
    }

    await _storage.setApiUrl(url);
    setState(() => _isEditingApiUrl = false);

    // 重新初始化 API
    _chatProvider.disconnect();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    if (password.length < 4) {
      _showError('密码至少4个字符');
      return;
    }

    await _storage.setPassword(password);
    setState(() => _isEditingPassword = false);
    _passwordController.clear();
  }

  Future<void> _updateBotName() async {
    final name = _botNameController.text.trim();
    if (name.isEmpty) {
      _showError('请输入 Bot 名称');
      return;
    }

    await _storage.setBotName(name);
    await _authProvider.updateBotConfig(name: name);
    setState(() => _isEditingBotName = false);
  }

  Future<void> _updateBotUsername() async {
    final username = _botUsernameController.text.trim();
    if (username.isEmpty) {
      _showError('请输入 Bot 唯一标识符');
      return;
    }

    await _storage.setBotUsername(username);
    setState(() => _isEditingBotUsername = false);

    // 断开旧连接，用新的 bot username 重新连接
    final userUsername = _storage.getUsername() ?? '';
    await _chatProvider.disconnect();
    await _chatProvider.connectToChat(
      botUsername: username,
      username: userUsername,
    );
  }

  Future<void> _clearOldMessages() async {
    setState(() => _isLoading = true);

    try {
      await _storage.clearOldMessages(_storage.getBotUsername() ?? 'default');
      // 刷新 ChatProvider 内存中的消息列表
      await _chatProvider.loadRecentMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除2天前的聊天记录')),
        );
      }
    } catch (e) {
      _showError('清除失败');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authProvider.logout();
      await _chatProvider.disconnect();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildThemePicker(),
    );
  }

  Widget _buildThemePicker() {
    final colors = _themeProvider.getPresetColors();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '选择主题色',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // 系统动态颜色
              GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await _themeProvider.useSystemDynamicColors();
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple, Colors.orange],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                  ),
                ),
              ),
              // 预设颜色
              ...colors.map((color) => GestureDetector(
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _themeProvider.setThemeColor(color);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AboutPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAvatar = _storage.getUserAvatar();
    final botAvatar = _storage.getBotAvatar();
    final botName = _storage.getBotName() ?? 'Bot';
    final username = _storage.getUsername() ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // API 配置
          _buildSectionHeader('服务器'),
          _buildApiUrlTile(),

          const SizedBox(height: 16),

          // 用户配置
          _buildSectionHeader('用户'),
          _buildUserAvatarTile(userAvatar),
          _buildPasswordTile(),

          const SizedBox(height: 16),

          // Bot 配置
          _buildSectionHeader('Bot'),
          _buildBotAvatarTile(botAvatar),
          _buildBotUsernameTile(_storage.getBotUsername() ?? ''),
          _buildBotNameTile(botName),

          const SizedBox(height: 16),

          // 主题
          _buildSectionHeader('外观'),
          _buildThemeTile(),

          const SizedBox(height: 16),

          // 数据
          _buildSectionHeader('数据'),
          _buildClearMessagesTile(),

          const SizedBox(height: 16),

          // 关于
          _buildSectionHeader('关于'),
          _buildAboutTile(),

          const SizedBox(height: 32),

          // 退出登录按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _logout,
              child: const Text('退出登录'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildApiUrlTile() {
    return ListTile(
      title: _isEditingApiUrl
          ? TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                border: OutlineInputBorder(),
              ),
            )
          : const Text('API 地址'),
      subtitle: _isEditingApiUrl ? null : Text(_storage.getApiUrl() ?? '未设置'),
      trailing: _isEditingApiUrl
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _updateApiUrl,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _isEditingApiUrl = false);
                    _apiUrlController.text = _storage.getApiUrl();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : IconButton(
              onPressed: () => setState(() => _isEditingApiUrl = true),
              icon: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildUserAvatarTile(String? avatar) {
    return ListTile(
      leading: UserAvatar(imageUrl: avatar, size: 40),
      title: const Text('用户头像'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _pickUserAvatar,
            child: const Text('更换'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTile() {
    return ListTile(
      title: _isEditingPassword
          ? Column(
              children: [
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '新密码',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _isEditingPassword = false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updatePassword,
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            )
          : const Text('密码'),
      subtitle: _isEditingPassword ? null : const Text('********'),
      trailing: _isEditingPassword
          ? null
          : IconButton(
              onPressed: () => setState(() => _isEditingPassword = true),
              icon: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildBotAvatarTile(String? avatar) {
    return ListTile(
      leading: BotAvatar(imageUrl: avatar, size: 40),
      title: const Text('Bot 头像'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _pickBotAvatar,
            child: const Text('更换'),
          ),
        ],
      ),
    );
  }

  Widget _buildBotNameTile(String currentName) {
    return ListTile(
      title: _isEditingBotName
          ? TextField(
              controller: _botNameController,
              decoration: const InputDecoration(
                labelText: 'Bot 名称',
                border: OutlineInputBorder(),
              ),
            )
          : const Text('Bot 名称'),
      subtitle: _isEditingBotName ? null : Text(currentName),
      trailing: _isEditingBotName
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _updateBotName,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _isEditingBotName = false);
                    _botNameController.text = _storage.getBotName() ?? '';
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : IconButton(
              onPressed: () => setState(() => _isEditingBotName = true),
              icon: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildBotUsernameTile(String currentUsername) {
    return ListTile(
      title: _isEditingBotUsername
          ? TextField(
              controller: _botUsernameController,
              decoration: const InputDecoration(
                labelText: 'Bot 唯一标识符',
                border: OutlineInputBorder(),
              ),
            )
          : const Text('Bot 唯一标识符'),
      subtitle: _isEditingBotUsername
          ? null
          : Text(currentUsername.isNotEmpty ? currentUsername : '未设置'),
      trailing: _isEditingBotUsername
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _updateBotUsername,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _isEditingBotUsername = false);
                    _botUsernameController.text =
                        _storage.getBotUsername() ?? '';
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : IconButton(
              onPressed: () => setState(() => _isEditingBotUsername = true),
              icon: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildThemeTile() {
    return SwitchListTile(
      title: const Text('深色模式'),
      subtitle: Text(_themeProvider.isDarkMode() ? '已开启' : '已关闭'),
      value: _themeProvider.isDarkMode(),
      onChanged: (value) async {
        await _themeProvider.toggleDarkMode();
      },
    );
  }

  Widget _buildClearMessagesTile() {
    return ListTile(
      title: const Text('清除旧聊天记录'),
      subtitle: const Text('清除2天前的本地聊天记录'),
      trailing: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline),
      onTap: _isLoading ? null : _clearOldMessages,
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('关于'),
      subtitle: const Text('版本信息、开发者信息'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _openAbout,
    );
  }
}
