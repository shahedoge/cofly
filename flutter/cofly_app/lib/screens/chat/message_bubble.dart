import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../components/avatar.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUserMessage;
  final String? userName;
  final String? botName;
  final String? userAvatar;
  final String? botAvatar;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUserMessage,
    this.userName,
    this.botName,
    this.userAvatar,
    this.botAvatar,
    this.onDelete,
  });

  void _showContextMenu(BuildContext context, Offset position) {
    final isTextType =
        message.type == MessageType.text || message.type == MessageType.audio;

    final items = <PopupMenuEntry<String>>[
      if (isTextType)
        const PopupMenuItem(value: 'copy', child: Text('复制')),
      const PopupMenuItem(value: 'delete', child: Text('删除')),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: items,
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: message.content));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else if (value == 'delete') {
        onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: isUserMessage
          ? _buildUserMessage(context)
          : _buildBotMessage(context),
    );
  }

  /// 根据消息类型构建内容 widget
  Widget _buildMessageContent(BuildContext context, {required bool isBotStyle}) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.file:
        return _buildFileContent(context);
      default:
        if (isBotStyle) {
          return MarkdownBody(
            data: message.content,
            selectable: true,
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                height: 1.4,
              ),
              code: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                fontSize: 14,
              ),
            ),
          );
        } else {
          return Text(
            message.content,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 16,
            ),
          );
        }
    }
  }

  /// 图片消息渲染
  Widget _buildImageContent(BuildContext context) {
    Widget imageWidget;

    // content 以 / 开头 → 本地文件预览
    if (message.content.startsWith('/')) {
      imageWidget = Image.file(
        File(message.content),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImagePlaceholder(context),
      );
    } else {
      // 尝试解析 JSON 取 image_key
      String? imageKey;
      try {
        final decoded = jsonDecode(message.content);
        if (decoded is Map) {
          imageKey = decoded['image_key'] as String?;
        }
      } catch (_) {}

      if (imageKey != null && imageKey.isNotEmpty) {
        final url =
            '${ApiService().baseUrl}/open-apis/im/v1/images/$imageKey';
        imageWidget = Image.network(
          url,
          fit: BoxFit.cover,
          headers: const {},
          errorBuilder: (_, __, ___) => _brokenImagePlaceholder(context),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 120,
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        );
      } else {
        imageWidget = _brokenImagePlaceholder(context);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
        child: imageWidget,
      ),
    );
  }

  Widget _brokenImagePlaceholder(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.broken_image,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 文件消息渲染
  Widget _buildFileContent(BuildContext context) {
    String fileName = '未知文件';
    try {
      final decoded = jsonDecode(message.content);
      if (decoded is Map) {
        fileName = (decoded['file_name'] as String?) ?? fileName;
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// 用户消息 (右侧，气泡样式)
  Widget _buildUserMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 消息内容
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 用户名和时间
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName ?? '你',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // 气泡
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: message.type == MessageType.image
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildMessageContent(context, isBotStyle: false),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // 头像
          UserAvatar(imageUrl: userAvatar, size: 36),
        ],
      ),
    );
  }

  /// Bot 消息 (左侧，无气泡样式)
  Widget _buildBotMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 头像
          BotAvatar(imageUrl: botAvatar, size: 36),
          const SizedBox(width: 8),
          // 消息内容
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bot名称和时间
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      botName ?? 'Bot',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // 内容
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: _buildMessageContent(context, isBotStyle: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return DateFormat('HH:mm').format(time);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${DateFormat('HH:mm').format(time)}';
    } else {
      return DateFormat('MM/dd HH:mm').format(time);
    }
  }
}
