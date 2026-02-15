import 'dart:convert';

/// 消息类型
enum MessageType {
  text,
  image,
  audio,
  video,
  file,
}

/// 消息模型
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isFromBot;
  final bool isRead;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isFromBot,
    this.isRead = false,
  });

  /// 从 JSON 创建消息
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      chatId: json['chat_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      type: parseMessageType(json['type']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isFromBot: json['is_from_bot'] ?? false,
      isRead: json['is_read'] ?? false,
    );
  }

  /// 解析消息类型
  static MessageType parseMessageType(dynamic type) {
    if (type is String) {
      switch (type.toLowerCase()) {
        case 'image':
          return MessageType.image;
        case 'audio':
          return MessageType.audio;
        case 'video':
          return MessageType.video;
        case 'file':
          return MessageType.file;
        default:
          return MessageType.text;
      }
    } else if (type is int) {
      switch (type) {
        case 1:
          return MessageType.image;
        case 2:
          return MessageType.audio;
        case 3:
          return MessageType.video;
        case 4:
          return MessageType.file;
        default:
          return MessageType.text;
      }
    }
    return MessageType.text;
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'type': type.index,
      'created_at': createdAt.toIso8601String(),
      'is_from_bot': isFromBot,
      'is_read': isRead,
    };
  }

  /// 转换为 Hive 存储格式
  Map<String, dynamic> toHiveJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'type': type.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isFromBot': isFromBot,
      'isRead': isRead,
    };
  }

  /// 从 Hive 格式创建消息
  factory Message.fromHiveJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.values[json['type'] ?? 0],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      isFromBot: json['isFromBot'] ?? false,
      isRead: json['isRead'] ?? false,
    );
  }

  /// 复制消息并修改部分字段
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    MessageType? type,
    DateTime? createdAt,
    bool? isFromBot,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isFromBot: isFromBot ?? this.isFromBot,
      isRead: isRead ?? this.isRead,
    );
  }

  /// 从服务器消息 item 创建 Message
  /// item 格式: {message_id, chat_id, msg_type, body: {content: "..."}, sender: {id: "..."}, create_time: "ms"}
  factory Message.fromServerItem(
    Map<String, dynamic> item, {
    required String localChatId,
    required String botOpenId,
  }) {
    final messageId = item['message_id'] as String? ?? '';
    final msgType = item['msg_type'] as String? ?? 'text';
    final body = item['body'] as Map<String, dynamic>? ?? {};
    final contentStr = body['content'] as String? ?? '';
    final sender = item['sender'] as Map<String, dynamic>? ?? {};
    final senderId = sender['id'] as String? ?? '';
    final createTimeStr = item['create_time'] as String? ?? '0';

    const rawPassthroughTypes = {'image', 'file', 'audio', 'video'};
    final textContent = rawPassthroughTypes.contains(msgType)
        ? contentStr
        : extractTextContent(contentStr);

    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(int.tryParse(createTimeStr) ?? 0);

    return Message(
      id: messageId,
      chatId: localChatId,
      senderId: senderId,
      content: textContent,
      type: parseMessageType(msgType),
      createdAt: createdAt,
      isFromBot: senderId == botOpenId,
    );
  }

  /// 从消息 content JSON 中提取文本内容（共享工具方法）
  /// 支持: {"text":"..."} / {"<lang>":{"content":[[{"tag":"...","text":"..."}]]}}
  ///       / 卡片格式 {"schema":"2.0","body":{"elements":[{"tag":"markdown","content":"..."}]}}
  ///       / 原始字符串
  static String extractTextContent(String contentStr) {
    try {
      final decoded = jsonDecode(contentStr);
      if (decoded is Map) {
        // 简单文本格式: {"text":"hello"}
        if (decoded.containsKey('text')) {
          return decoded['text'] as String;
        }

        // 卡片格式 (schema 2.0)
        if (decoded.containsKey('schema') && decoded.containsKey('body')) {
          final body = decoded['body'];
          if (body is Map) {
            final elements = body['elements'] as List<dynamic>?;
            if (elements != null) {
              final parts = <String>[];
              for (final el in elements) {
                if (el is Map &&
                    el['tag'] == 'markdown' &&
                    el.containsKey('content')) {
                  parts.add(el['content'] as String);
                }
              }
              if (parts.isNotEmpty) return parts.join('\n\n');
            }
          }
        }

        // 富文本格式
        for (final langKey in decoded.keys) {
          final langVal = decoded[langKey];
          if (langVal is Map) {
            final content = langVal['content'] as List<dynamic>?;
            if (content != null) {
              final parts = <String>[];
              for (final row in content) {
                if (row is List) {
                  for (final element in row) {
                    if (element is Map && element.containsKey('text')) {
                      parts.add(element['text'] as String);
                    }
                  }
                }
              }
              if (parts.isNotEmpty) return parts.join('\n');
            }
          }
        }
      }
    } catch (_) {}
    return contentStr;
  }

  @override
  String toString() {
    return 'Message(id: $id, content: $content, isFromBot: $isFromBot)';
  }
}

/// 发送消息请求
class SendMessageRequest {
  final String chatId;
  final String content;
  final MessageType type;

  SendMessageRequest({
    required this.chatId,
    required this.content,
    this.type = MessageType.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'content': content,
      'type': type.index,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

/// 消息列表响应
class MessageListResponse {
  /// 服务器返回的原始 item 列表，需要调用方用 Message.fromServerItem() 转换
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final String? nextCursor;

  MessageListResponse({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  factory MessageListResponse.fromJson(Map<String, dynamic> json) {
    // 服务器返回格式: {code: 0, data: {items: [...], has_more: bool, page_token: "..."}}
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final rawItems = (data['items'] as List<dynamic>?) ?? [];

    return MessageListResponse(
      items: rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      hasMore: data['has_more'] ?? false,
      nextCursor: data['page_token'] as String?,
    );
  }
}

/// WebSocket 消息事件
class WsMessageEvent {
  final String eventType;
  final Map<String, dynamic> data;

  WsMessageEvent({
    required this.eventType,
    required this.data,
  });

  factory WsMessageEvent.fromJson(Map<String, dynamic> json) {
    return WsMessageEvent(
      eventType: json['event_type'] ?? json['event'] ?? '',
      data: json['data'] ?? {},
    );
  }
}

/// 消息送达确认
class MessageAck {
  final String messageId;
  final String chatId;
  final DateTime timestamp;

  MessageAck({
    required this.messageId,
    required this.chatId,
    required this.timestamp,
  });

  factory MessageAck.fromJson(Map<String, dynamic> json) {
    return MessageAck(
      messageId: json['message_id'] ?? '',
      chatId: json['chat_id'] ?? '',
      timestamp:
          json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
