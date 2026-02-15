import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'storage_service.dart';

/// API 服务异常
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// API 服务
class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Dio instance
  late Dio _dio;
  final StorageService _storage = StorageService();

  // 当前 token（登录后设置，所有后续请求自动携带）
  String? _token;

  // Initialization
  void init() {
    final baseUrl = _storage.getApiUrl();
    debugPrint('[API] init baseUrl=$baseUrl');
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    // 拦截器：自动添加 Authorization header + 请求/响应日志
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        debugPrint('[API] >>> ${options.method} ${options.baseUrl}${options.path}');
        if (options.queryParameters.isNotEmpty) {
          debugPrint('[API]     query: ${options.queryParameters}');
        }
        if (options.data != null) {
          debugPrint('[API]     body: ${options.data}');
        }
        debugPrint('[API]     hasToken: ${_token != null && _token!.isNotEmpty}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('[API] <<< ${response.statusCode} ${response.requestOptions.path}');
        debugPrint('[API]     data: ${_truncate(response.data.toString(), 500)}');
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('[API] !!! ${error.type} ${error.requestOptions.path}');
        debugPrint('[API]     status: ${error.response?.statusCode}');
        debugPrint('[API]     data: ${error.response?.data}');
        debugPrint('[API]     message: ${error.message}');
        handler.next(error);
      },
    ));
  }

  static String _truncate(String s, int maxLen) {
    return s.length <= maxLen ? s : '${s.substring(0, maxLen)}...';
  }

  /// 更新 API URL
  void updateBaseUrl(String url) {
    debugPrint('[API] updateBaseUrl: $url');
    _dio.options.baseUrl = url;
  }

  /// 设置 auth token
  void setToken(String? token) {
    debugPrint('[API] setToken: ${token != null ? "${token!.substring(0, 20)}..." : "null"}');
    _token = token;
  }

  // ==================== Auth Endpoints ====================

  /// 用户登录（获取 token）
  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    debugPrint('[API] login: username=$username');
    try {
      final response = await _dio.post(
        '/open-apis/auth/v3/tenant_access_token/internal',
        data: {
          'app_id': username,
          'app_secret': password,
        },
      );

      final loginResponse = LoginResponse.fromJson(response.data);
      debugPrint('[API] login result: success=${loginResponse.success}, hasToken=${loginResponse.token != null}');
      if (loginResponse.success && loginResponse.token != null) {
        _token = loginResponse.token;
      }
      return loginResponse;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 用户注册
  Future<RegisterResponse> register({
    required String username,
    required String password,
    String? registrationToken,
  }) async {
    try {
      final response = await _dio.post(
        '/cofly/register',
        data: {
          'username': username,
          'password': password,
          'registration_token': registrationToken,
        },
      );

      return RegisterResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ==================== User Endpoints ====================

  /// 查询用户信息，获取 open_id
  /// 响应格式: {code: 0, data: {user: {open_id: "..."}}}
  Future<String> lookupUser(String username) async {
    debugPrint('[API] lookupUser: username=$username');
    try {
      final response = await _dio.get(
        '/cofly/users/$username',
      );

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        debugPrint('[API] lookupUser response body: $body');
        final code = body['code'] as int?;
        if (code == 0) {
          final data = body['data'] as Map<String, dynamic>?;
          final user = data?['user'] as Map<String, dynamic>?;
          final openId = user?['open_id'] as String?;
          debugPrint('[API] lookupUser: code=$code, data=$data, user=$user, openId=$openId');
          if (openId != null && openId.isNotEmpty) {
            return openId;
          }
        }
        throw ApiException(message: '用户 open_id 为空 (code=$code, body=$body)');
      }

      throw ApiException(
        message: '查询用户失败',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ==================== WebSocket Endpoints ====================

  /// 获取 WebSocket 连接端点（含 token）
  /// 响应格式: {code: 0, data: {URL: "ws://host/ws?token=..."}}
  Future<String> getWsEndpoint(String token) async {
    debugPrint('[API] getWsEndpoint: token=${token.substring(0, 20)}...');
    try {
      final response = await _dio.post(
        '/callback/ws/endpoint',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        debugPrint('[API] getWsEndpoint response body: $body');
        final code = body['code'] as int?;
        if (code == 0) {
          final data = body['data'] as Map<String, dynamic>?;
          debugPrint('[API] getWsEndpoint data keys: ${data?.keys.toList()}');
          final url = data?['URL'] as String?;
          debugPrint('[API] getWsEndpoint URL=$url');
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
        throw ApiException(message: 'WebSocket URL 为空 (body=$body)');
      }

      throw ApiException(
        message: '获取 WebSocket 端点失败',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ==================== Bot Endpoints ====================

  Future<BotInfo> getBotInfo() async {
    try {
      final response = await _dio.get(
        '/open-apis/bot/v3/info',
      );

      if (response.statusCode == 200) {
        return BotInfo.fromJson(response.data);
      }

      throw ApiException(
        message: '获取Bot信息失败',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ==================== Upload Endpoints ====================

  /// 上传图片，返回 image_key
  Future<String> uploadImage({
    required String filePath,
    void Function(double)? onProgress,
  }) async {
    debugPrint('[API] uploadImage: filePath=$filePath');
    try {
      final formData = FormData.fromMap({
        'image_type': 'message',
        'image': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '/open-apis/im/v1/images',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      final body = response.data as Map<String, dynamic>;
      final code = body['code'] as int?;
      if (code == 0) {
        final data = body['data'] as Map<String, dynamic>?;
        final imageKey = data?['image_key'] as String?;
        if (imageKey != null && imageKey.isNotEmpty) {
          debugPrint('[API] uploadImage success: image_key=$imageKey');
          return imageKey;
        }
      }
      throw ApiException(message: '上传图片失败: ${body['msg'] ?? 'unknown'}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 上传文件，返回 file_key
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    debugPrint('[API] uploadFile: filePath=$filePath, fileName=$fileName');
    try {
      final formData = FormData.fromMap({
        'file_type': 'stream',
        'file_name': fileName,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/open-apis/im/v1/files',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      final body = response.data as Map<String, dynamic>;
      final code = body['code'] as int?;
      if (code == 0) {
        final data = body['data'] as Map<String, dynamic>?;
        final fileKey = data?['file_key'] as String?;
        if (fileKey != null && fileKey.isNotEmpty) {
          debugPrint('[API] uploadFile success: file_key=$fileKey');
          return fileKey;
        }
      }
      throw ApiException(message: '上传文件失败: ${body['msg'] ?? 'unknown'}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 获取 API base URL（供 UI 层构造图片下载 URL）
  String get baseUrl => _dio.options.baseUrl;

  // ==================== Message Endpoints ====================

  /// 发送消息
  /// content 格式: text 类型需要 JSON 序列化为 '{"text":"..."}'
  /// 返回服务器分配的 message_id（用于去重）
  Future<String?> sendMessage({
    required String receiveId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    debugPrint('[API] sendMessage: receiveId=$receiveId, type=$type, content=${_truncate(content, 100)}');
    try {
      String encodedContent;
      if (type == MessageType.text) {
        encodedContent = jsonEncode({'text': content});
      } else if (type == MessageType.image) {
        encodedContent = jsonEncode({'image_key': content});
      } else {
        // file and other types: content is already JSON-encoded by caller
        encodedContent = content;
      }

      final response = await _dio.post(
        '/open-apis/im/v1/messages',
        queryParameters: {
          'receive_id_type': 'open_id',
        },
        data: {
          'receive_id': receiveId,
          'msg_type': type == MessageType.text ? 'text' : type.name,
          'content': encodedContent,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final code = body['code'] as int?;
      debugPrint('[API] sendMessage result: code=$code');
      if (code != 0) {
        throw ApiException(
          message: body['msg'] as String? ?? '发送消息失败',
          statusCode: response.statusCode,
        );
      }

      // Return server-assigned message_id
      final data = body['data'] as Map<String, dynamic>?;
      return data?['message_id'] as String?;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 获取消息列表
  Future<MessageListResponse> getMessages({
    required String chatId,
    int pageSize = 200,
    int? startTime,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page_size': pageSize,
      };

      if (startTime != null) {
        queryParams['start_time'] = startTime;
      }

      final response = await _dio.get(
        '/open-apis/im/v1/chats/$chatId/messages',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return MessageListResponse.fromJson(response.data);
      }

      throw ApiException(
        message: '获取消息列表失败',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ==================== Chat Endpoints ====================

  Future<ChatListResponse> getChatList() async {
    try {
      final response = await _dio.get(
        '/open-apis/im/v1/chats',
      );

      if (response.statusCode == 200) {
        return ChatListResponse.fromJson(response.data);
      }

      throw ApiException(
        message: '获取聊天列表失败',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ==================== Health Check ====================

  Future<bool> verifyApiConnection() async {
    try {
      final response = await _dio.get(
        '/open-apis/bot/v3/info',
        options: Options(validateStatus: (_) => true),
      );
      return response.statusCode != null;
    } catch (e) {
      return false;
    }
  }

  // ==================== Helper Methods ====================

  ApiException _handleDioException(DioException e) {
    String errorMessage = '';
    int? statusCode = e.response?.statusCode;

    if (e.response?.data != null && e.response!.data is Map<String, dynamic>) {
      final data = e.response!.data as Map<String, dynamic>;
      if (data['msg'] != null) {
        errorMessage = data['msg'] as String;
      } else if (data['detail'] != null) {
        errorMessage = data['detail'] as String;
      }
    }

    if (errorMessage.isEmpty) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage = '连接超时，请检查API地址是否正确';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage = '接收超时，请检查API地址是否正确';
          break;
        case DioExceptionType.badResponse:
          errorMessage = '服务器错误 (${e.response?.statusCode})';
          break;
        case DioExceptionType.connectionError:
          errorMessage = '无法连接到服务器，请检查API地址是否正确';
          break;
        case DioExceptionType.cancel:
          errorMessage = '请求被取消';
          break;
        default:
          errorMessage = '网络错误: ${e.message}';
      }
    }

    debugPrint('[API] Exception: $errorMessage (status=$statusCode)');
    return ApiException(
      message: errorMessage,
      statusCode: statusCode,
    );
  }
}
