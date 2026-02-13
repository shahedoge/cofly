import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/message.dart';
import '../components/avatar.dart';
import 'message_bubble.dart';

/// 消息列表组件
class ChatList extends StatelessWidget {
  final List<Message> messages;
  final ScrollController scrollController;
  final bool isLoading;
  final bool isWaitingReply;
  final String? currentUserId;
  final String? botUserId;
  final String? userName;
  final String? botName;
  final String? userAvatar;
  final String? botAvatar;
  final void Function(String messageId)? onDeleteMessage;

  const ChatList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.isLoading = false,
    this.isWaitingReply = false,
    this.currentUserId,
    this.botUserId,
    this.userName,
    this.botName,
    this.userAvatar,
    this.botAvatar,
    this.onDeleteMessage,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isWaitingReply ? 1 : 0);

    return Stack(
      children: [
        // 消息列表
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // 最后一项是 typing indicator
            if (isWaitingReply && index == messages.length) {
              return _TypingIndicator(
                botName: botName,
                botAvatar: botAvatar,
              );
            }

            final message = messages[index];
            final isUser = !message.isFromBot;

            return MessageBubble(
              message: message,
              isUserMessage: isUser,
              userName: userName,
              botName: botName,
              userAvatar: userAvatar,
              botAvatar: botAvatar,
              onDelete: onDeleteMessage != null
                  ? () => onDeleteMessage!(message.id)
                  : null,
            );
          },
        ),

        // 加载指示器
        if (isLoading)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 正在处理提示（三个跳动圆点）
class _TypingIndicator extends StatefulWidget {
  final String? botName;
  final String? botAvatar;

  const _TypingIndicator({this.botName, this.botAvatar});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          BotAvatar(imageUrl: widget.botAvatar, size: 36),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  widget.botName ?? 'Bot',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final delay = i * 0.2;
                        final t = (_controller.value - delay) % 1.0;
                        final opacity = (t < 0.5)
                            ? 0.3 + 0.7 * (t / 0.5)
                            : 0.3 + 0.7 * ((1.0 - t) / 0.5);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Opacity(
                            opacity: opacity.clamp(0.3, 1.0),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 空状态组件
class EmptyChatState extends StatelessWidget {
  const EmptyChatState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '开始对话',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '发送第一条消息开始聊天',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// 日期分隔符
class DateDivider extends StatelessWidget {
  final DateTime date;

  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date.isAfter(today)) {
      label = '今天';
    } else if (date.isAfter(yesterday)) {
      label = '昨天';
    } else {
      label = DateFormat('yyyy年M月d日').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
