import 'dart:convert';

/// 用户模型
class User {
  final String id;
  final String username;
  final String? password;
  final String? avatar;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    this.password,
    this.avatar,
    required this.createdAt,
  });

  /// 从 JSON 创建用户
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      password: json['password'],
      avatar: json['avatar'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 复制用户并修改部分字段
  User copyWith({
    String? id,
    String? username,
    String? password,
    String? avatar,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, avatar: $avatar)';
  }
}

/// 用户注册请求
class RegisterRequest {
  final String username;
  final String password;
  final String? registrationToken;

  RegisterRequest({
    required this.username,
    required this.password,
    this.registrationToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'registration_token': registrationToken,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

/// 登录响应（token endpoint）
class LoginResponse {
  final bool success;
  final String? message;
  final String? token;
  final int? expire;

  LoginResponse({
    required this.success,
    this.message,
    this.token,
    this.expire,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as int?;
    final msg = json['msg'] as String?;
    final token = json['tenant_access_token'] as String?;
    final expire = json['expire'] as int?;

    return LoginResponse(
      success: code == 0,
      message: msg,
      token: (token != null && token.isNotEmpty) ? token : null,
      expire: expire,
    );
  }
}

/// 用户注册响应
class RegisterResponse {
  final bool success;
  final String? message;
  final User? user;

  RegisterResponse({
    required this.success,
    this.message,
    this.user,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    // 解析 Cofly API 响应格式: {code: 0, msg: "...", data: {...}}
    final code = json['code'] as int?;
    final msg = json['msg'] as String?;
    final data = json['data'] as Map<String, dynamic>?;

    // code == 0 表示成功
    final isSuccess = code == 0;

    // 解析用户数据
    User? user;
    if (data != null) {
      user = User.fromJson(data);
    }

    return RegisterResponse(
      success: isSuccess,
      message: msg,
      user: user,
    );
  }
}
