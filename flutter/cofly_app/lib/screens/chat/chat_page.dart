import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../services/storage_service.dart';
import '../components/menu_button.dart';
import 'chat_list.dart';
import 'input_bar.dart';

/// 聊天页面
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatProvider _chatProvider;
  late final StorageService _storage;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _storage = StorageService();

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _storage.init();
    await _chatProvider.init();

    final username = _storage.getUsername() ?? '';
    final botUsername = _storage.getBotUsername() ?? '';

    await _chatProvider.connectToChat(
      botUsername: botUsername,
      username: username,
    );
  }

  void _sendMessage(String content) {
    _chatProvider.sendMessage(content);
  }

  void _openSettings() {
    Navigator.of(context).pushNamed('/settings');
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildMoreMenu(),
    );
  }

  Widget _buildMoreMenu() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('搜索聊天记录'),
            onTap: () {
              Navigator.of(context).pop();
              _showSearchDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清空聊天记录'),
            onTap: () {
              Navigator.of(context).pop();
              _showClearConfirmDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: '输入搜索内容',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearHistory();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _clearHistory() async {
    await _chatProvider.clearHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('聊天记录已清空')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messages;
    final isLoading = chatProvider.isLoading;
    final isSending = chatProvider.isSending;
    final isConnected = chatProvider.isConnected;
    final isWaitingReply = chatProvider.isWaitingReply;

    final botName = _storage.getBotName() ?? 'Bot';

    return Scaffold(
      appBar: AppBar(
        leading: MenuButton(
          onPressed: _openSettings,
          icon: Icons.menu,
          tooltip: '设置',
        ),
        title: Text(botName),
        actions: [
          MenuButton(
            onPressed: _showMoreMenu,
            icon: Icons.more_vert,
            tooltip: '更多',
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表或空状态
          Expanded(
            child: Stack(
              children: [
                ChatList(
                  messages: messages,
                  scrollController: _chatProvider.scrollController,
                  isLoading: isLoading,
                  isWaitingReply: isWaitingReply,
                  botName: botName,
                  botAvatar: _storage.getBotAvatar(),
                  userAvatar: _storage.getUserAvatar(),
                  onDeleteMessage: (id) => _chatProvider.deleteMessage(id),
                ),
                if (messages.isEmpty && !isLoading)
                  const EmptyChatState(),
              ],
            ),
          ),

          // 输入栏
          InputBar(
            onSend: _sendMessage,
            isSending: isSending,
            isConnected: isConnected,
          ),
        ],
      ),
    );
  }
}
