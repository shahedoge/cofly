import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/ws_service.dart';
import '../utils/constants.dart';
import '../utils/platform_helper.dart';

/// 聊天提供者
class ChatProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();
  final WsService _wsService = WsService();

  // State
  List<Message> _messages = [];
  List<Chat> _chats = [];
  String _currentChatId = '';
  String? _botOpenId;
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isSending = false;
  bool _isWaitingReply = false;
  String? _errorMessage;
  double? _uploadProgress;

  // Scroll controller for message list
  final ScrollController scrollController = ScrollController();

  // Getters
  List<Message> get messages => _messages;
  List<Chat> get chats => _chats;
  String get currentChatId => _currentChatId;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isWaitingReply => _isWaitingReply;
  String? get errorMessage => _errorMessage;
  bool get isUploading => _uploadProgress != null;
  double? get uploadProgress => _uploadProgress;

  // ==================== Lifecycle ====================

  ChatProvider() {
    // Listen to WebSocket connection state
    _wsService.connectionStateStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });

    // Listen to incoming messages
    _wsService.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });
  }

  /// 初始化
  Future<void> init() async {
    await _storage.init();
    _api.init();
  }

  /// 连接到聊天
  Future<void> connectToChat({
    required String botUsername,
    required String username,
  }) async {
    _currentChatId = botUsername;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 先登录获取 token（确保后续 API 调用有 auth）
      final password = await _storage.getPassword();
      if (password != null && password.isNotEmpty) {
        await _api.login(username: username, password: password);
      }

      // 查询 bot 的 open_id
      _botOpenId = await _api.lookupUser(botUsername);
      debugPrint('[Chat] connectToChat: botOpenId=$_botOpenId');

      // 连接 WebSocket
      await _wsService.connect(
        chatId: botUsername,
        username: username,
      );

      // 加载本地历史消息
      await loadRecentMessages();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _wsService.disconnect();
    _currentChatId = '';
    _messages.clear();
  }

  // ==================== Message Operations ====================

  /// 加载最近消息
  Future<void> loadRecentMessages({int days = 2}) async {
    if (_currentChatId.isEmpty) return;

    try {
      _messages = await _storage.getRecentMessages(
        _currentChatId,
        days: days,
      );

      // 按时间排序
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // 滚动到底部
      _scrollToBottom();
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// 发送消息
  Future<bool> sendMessage(String content,
      {MessageType type = MessageType.text}) async {
    debugPrint('[Chat] sendMessage: content="${content.length > 50 ? "${content.substring(0, 50)}..." : content}", botOpenId=$_botOpenId, currentChatId=$_currentChatId');
    if (_currentChatId.isEmpty || content.trim().isEmpty) {
      debugPrint('[Chat] sendMessage skipped: chatId empty or content empty');
      return false;
    }

    _isSending = true;
    notifyListeners();

    try {
      // 创建本地消息
      final localMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: _currentChatId,
        senderId: _storage.getUsername() ?? '',
        content: content.trim(),
        type: type,
        createdAt: DateTime.now(),
        isFromBot: false,
      );

      // 添加到本地列表
      _messages.add(localMessage);
      notifyListeners();

      // 保存到本地
      debugPrint('[Chat] saving message locally...');
      await _storage.saveMessage(localMessage);
      debugPrint('[Chat] message saved locally');

      // 发送到 API
      try {
        if (_botOpenId != null) {
          debugPrint('[Chat] sending to API: receiveId=$_botOpenId');
          await _api.sendMessage(
            receiveId: _botOpenId!,
            content: content.trim(),
            type: type,
          );
          debugPrint('[Chat] sendMessage API success');
          _isWaitingReply = true;
          notifyListeners();
        } else {
          debugPrint('[Chat] sendMessage skipped: _botOpenId is null');
        }
      } catch (e) {
        debugPrint('[Chat] sendMessage API error: $e');
        _errorMessage = '消息发送失败: $e';
      }

      // 滚动到底部
      _scrollToBottom();

      return true;
    } catch (e) {
      debugPrint('[Chat] sendMessage outer error: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// 发送图片消息
  Future<bool> sendImageMessage(String filePath) async {
    if (_currentChatId.isEmpty) return false;

    _uploadProgress = 0.0;
    notifyListeners();

    try {
      // 创建本地预览消息（content = 本地路径）
      final localMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: _currentChatId,
        senderId: _storage.getUsername() ?? '',
        content: filePath,
        type: MessageType.image,
        createdAt: DateTime.now(),
        isFromBot: false,
      );
      _messages.add(localMessage);
      notifyListeners();
      await _storage.saveMessage(localMessage);
      _scrollToBottom();

      // 上传获取 image_key
      final imageKey = await _api.uploadImage(
        filePath: filePath,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );

      // 更新本地消息 content 为 image_key JSON
      final idx = _messages.indexWhere((m) => m.id == localMessage.id);
      if (idx >= 0) {
        final updated = localMessage.copyWith(
          content: jsonEncode({'image_key': imageKey}),
        );
        _messages[idx] = updated;
        await _storage.saveMessage(updated);
      }

      // 发送到 API
      if (_botOpenId != null) {
        await _api.sendMessage(
          receiveId: _botOpenId!,
          content: imageKey,
          type: MessageType.image,
        );
        _isWaitingReply = true;
      }

      return true;
    } catch (e) {
      debugPrint('[Chat] sendImageMessage error: $e');
      _errorMessage = '图片发送失败: $e';
      return false;
    } finally {
      _uploadProgress = null;
      notifyListeners();
    }
  }

  /// 发送文件消息
  Future<bool> sendFileMessage(String filePath, String fileName) async {
    if (_currentChatId.isEmpty) return false;

    _uploadProgress = 0.0;
    notifyListeners();

    try {
      // 创建本地预览消息
      final localContent = jsonEncode({
        'file_name': fileName,
        'local_path': filePath,
      });
      final localMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: _currentChatId,
        senderId: _storage.getUsername() ?? '',
        content: localContent,
        type: MessageType.file,
        createdAt: DateTime.now(),
        isFromBot: false,
      );
      _messages.add(localMessage);
      notifyListeners();
      await _storage.saveMessage(localMessage);
      _scrollToBottom();

      // 上传获取 file_key
      final fileKey = await _api.uploadFile(
        filePath: filePath,
        fileName: fileName,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );

      // 更新本地消息 content
      final serverContent = jsonEncode({
        'file_key': fileKey,
        'file_name': fileName,
      });
      final idx = _messages.indexWhere((m) => m.id == localMessage.id);
      if (idx >= 0) {
        final updated = localMessage.copyWith(content: serverContent);
        _messages[idx] = updated;
        await _storage.saveMessage(updated);
      }

      // 发送到 API
      if (_botOpenId != null) {
        await _api.sendMessage(
          receiveId: _botOpenId!,
          content: serverContent,
          type: MessageType.file,
        );
        _isWaitingReply = true;
      }

      return true;
    } catch (e) {
      debugPrint('[Chat] sendFileMessage error: $e');
      _errorMessage = '文件发送失败: $e';
      return false;
    } finally {
      _uploadProgress = null;
      notifyListeners();
    }
  }

  /// 处理收到的消息（包括新消息和更新消息）
  void _handleIncomingMessage(Message message) {
    // 统一 chatId 为 _currentChatId（botUsername），确保本地存储 key 一致
    if (_currentChatId.isNotEmpty && message.chatId != _currentChatId) {
      message = message.copyWith(chatId: _currentChatId);
    }

    // Bot 回复到达，取消等待提示
    if (message.isFromBot && _isWaitingReply) {
      _isWaitingReply = false;
    }

    // 检查是否已存在（更新事件：替换已有消息内容）
    final existingIndex = _messages.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      _messages[existingIndex] = message;
    } else {
      _messages.add(message);
      // Only notify for genuinely new messages from bot (not stream updates)
      if (message.isFromBot) {
        _maybeShowNotification(message);
      }
    }
    notifyListeners();

    // 保存到本地
    _storage.saveMessage(message);

    // 滚动到底部
    _scrollToBottom();
  }

  /// 清除历史消息
  Future<void> clearHistory() async {
    await _storage.clearOldMessages(_currentChatId);
    _messages.clear();
    notifyListeners();
  }

  /// 搜索消息
  Future<List<Message>> searchMessages(String keyword) async {
    return await _storage.searchMessages(_currentChatId, keyword);
  }

  /// 删除单条消息
  Future<void> deleteMessage(String messageId) async {
    final message = _messages.firstWhere((m) => m.id == messageId,
        orElse: () => _messages.first);
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
    await _storage.deleteMessage(message);
  }

  // ==================== Chat Operations ====================

  /// 加载聊天列表
  Future<void> loadChatList() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.getChatList();
      _chats = response.chats;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== Helpers ====================

  /// Show notification if window is not focused/visible
  Future<void> _maybeShowNotification(Message message) async {
    bool shouldNotify = true;
    if (PlatformHelper.isDesktop) {
      final isFocused = await windowManager.isFocused();
      final isVisible = await windowManager.isVisible();
      shouldNotify = !isFocused || !isVisible;
    }
    if (shouldNotify) {
      final body = message.content.length > 100
          ? '${message.content.substring(0, 100)}...'
          : message.content;
      await NotificationService().showMessageNotification(
        title: 'Cofly',
        body: body,
      );
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients &&
          scrollController.positions.length == 1) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    scrollController.dispose();
    _wsService.dispose();
    super.dispose();
  }
}
