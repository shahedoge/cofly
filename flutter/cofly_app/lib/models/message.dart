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
  final List<Message> messages;
  final bool hasMore;
  final String? nextCursor;

  MessageListResponse({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  factory MessageListResponse.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>?)
            ?.map((e) => Message.fromJson(e))
            .toList() ??
        [];

    return MessageListResponse(
      messages: messages,
      hasMore: json['has_more'] ?? false,
      nextCursor: json['next_cursor'],
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
