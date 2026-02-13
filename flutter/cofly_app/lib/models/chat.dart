import 'dart:convert';

/// 聊天模型
class Chat {
  final String id;
  final String name;
  final String? avatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  Chat({
    required this.id,
    required this.name,
    this.avatar,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  /// 从 JSON 创建聊天
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : DateTime.now(),
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.toIso8601String(),
      'unread_count': unreadCount,
    };
  }

  /// 复制聊天并修改部分字段
  Chat copyWith({
    String? id,
    String? name,
    String? avatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  String toString() {
    return 'Chat(id: $id, name: $name)';
  }
}

/// Bot 信息
class BotInfo {
  final String id;
  final String name;
  final String? avatar;
  final String? description;

  BotInfo({
    required this.id,
    required this.name,
    this.avatar,
    this.description,
  });

  factory BotInfo.fromJson(Map<String, dynamic> json) {
    return BotInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'description': description,
    };
  }
}

/// 聊天列表响应
class ChatListResponse {
  final List<Chat> chats;

  ChatListResponse({required this.chats});

  factory ChatListResponse.fromJson(Map<String, dynamic> json) {
    final chats = (json['chats'] as List<dynamic>?)
            ?.map((e) => Chat.fromJson(e))
            .toList() ??
        [];

    return ChatListResponse(chats: chats);
  }
}
