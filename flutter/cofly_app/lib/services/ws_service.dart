import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/message.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/pbbp2.dart';

/// WebSocket 服务 — 使用 pbbp2 protobuf 二进制帧与 cofly 后端通信
class WsService {
  // Singleton
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  // Dependencies
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  // WebSocket channel
  WebSocketChannel? _channel;

  // Connection state
  bool _isConnected = false;
  bool _intentionalDisconnect = false;
  String? _chatId;
  String? _username;
  String? _botOpenId;

  // Timers
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _pingSeqId = 1;

  // Streams
  final _messageStream = StreamController<(Message, String)>.broadcast();
  final _connectionStateStream = StreamController<bool>.broadcast();

  // ==================== Connection Management ====================

  bool get isConnected => _isConnected;
  Stream<(Message, String)> get messageStream => _messageStream.stream;
  Stream<bool> get connectionStateStream => _connectionStateStream.stream;

  /// 连接 WebSocket
  Future<void> connect({
    required String chatId,
    required String username,
    String? botOpenId,
  }) async {
    debugPrint('[WS] connect called: chatId=$chatId, username=$username, botOpenId=$botOpenId');

    if (_isConnected) {
      debugPrint('[WS] already connected, disconnecting first');
      await disconnect();
    }

    _chatId = chatId;
    _username = username;
    _botOpenId = botOpenId;
    _intentionalDisconnect = false;

    final apiUrl = _storage.getApiUrl();
    if (apiUrl.isEmpty) {
      debugPrint('[WS] ERROR: API URL is empty');
      throw Exception('API URL not configured');
    }

    try {
      // 获取登录 token
      final password = await _storage.getPassword();
      debugPrint('[WS] password loaded: hasPassword=${password != null && password.isNotEmpty}');
      if (password == null || password.isEmpty) {
        throw Exception('未登录，无法获取 token');
      }

      debugPrint('[WS] logging in as $username...');
      final loginResponse = await _api.login(
        username: username,
        password: password,
      );
      debugPrint('[WS] login result: success=${loginResponse.success}, hasToken=${loginResponse.token != null}');
      if (loginResponse.token == null) {
        throw Exception('获取 token 失败: ${loginResponse.message}');
      }

      // 通过 token 获取 WebSocket 端点 URL
      debugPrint('[WS] getting WS endpoint...');
      final wsEndpoint = await _api.getWsEndpoint(loginResponse.token!);
      debugPrint('[WS] WS endpoint: $wsEndpoint');

      // 服务端在反向代理后可能返回 ws:// 而非 wss://，
      // 根据 API URL 的 scheme 修正 WebSocket URL
      final correctedEndpoint = _correctWsScheme(wsEndpoint, apiUrl);
      debugPrint('[WS] corrected WS endpoint: $correctedEndpoint');

      debugPrint('[WS] connecting to WebSocket...');
      _channel = WebSocketChannel.connect(
        Uri.parse(correctedEndpoint),
      );

      // 等待底层连接真正建立，避免假连接
      await _channel!.ready;

      // 监听数据
      _channel!.stream.listen(
        _handleRawData,
        onError: _handleError,
        onDone: _handleDone,
      );

      // 发送 ping 握手
      debugPrint('[WS] sending initial ping...');
      _sendPing();

      // 启动心跳定时器
      _startPingTimer();

      _isConnected = true;
      _connectionStateStream.add(true);
      debugPrint('[WS] connected successfully!');
    } catch (e, stack) {
      debugPrint('[WS] connect FAILED: $e');
      debugPrint('[WS] stack: $stack');
      _isConnected = false;
      _scheduleReconnect();
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    debugPrint('[WS] disconnect called');
    _intentionalDisconnect = true;
    _stopPingTimer();
    _cancelReconnect();

    if (_channel != null) {
      await _channel!.sink.close(ws_status.normalClosure);
      _channel = null;
    }

    _isConnected = false;
    _connectionStateStream.add(false);
  }

  /// 重新连接
  Future<void> reconnect() async {
    debugPrint('[WS] reconnect called: chatId=$_chatId, username=$_username');
    if (_chatId == null || _username == null) {
      debugPrint('[WS] reconnect skipped: no chatId or username');
      return;
    }

    await disconnect();
    await Future.delayed(const Duration(seconds: 2));
    await connect(chatId: _chatId!, username: _username!, botOpenId: _botOpenId);
  }

  // ==================== Frame Handling ====================

  /// 处理收到的原始数据
  void _handleRawData(dynamic data) {
    try {
      Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is List<int>) {
        bytes = Uint8List.fromList(data);
      } else {
        debugPrint('[WS] received non-binary data: ${data.runtimeType} = ${data.toString().substring(0, 200)}');
        return;
      }

      debugPrint('[WS] received ${bytes.length} bytes');

      final frame = parseFrame(bytes);
      final frameType = frame.getHeader('type');
      debugPrint('[WS] frame: method=${frame.method}, type=$frameType, seqId=${frame.seqId}, payloadLen=${frame.payload.length}');

      if (frameType == 'pong') {
        debugPrint('[WS] pong received');
        return;
      }

      // method == 1 表示事件推送
      if (frame.method == 1 && frame.payload.isNotEmpty) {
        final payloadStr = frame.payloadString;
        debugPrint('[WS] event payload: ${payloadStr.length > 300 ? "${payloadStr.substring(0, 300)}..." : payloadStr}');
        _handleEventPayload(payloadStr);
      }
    } catch (e, stack) {
      debugPrint('[WS] _handleRawData error: $e');
      debugPrint('[WS] stack: $stack');
    }
  }

  /// 处理事件 JSON payload
  void _handleEventPayload(String payloadStr) {
    try {
      final Map<String, dynamic> evt = jsonDecode(payloadStr);
      final header = evt['header'] as Map<String, dynamic>?;
      final eventType = header?['event_type'] as String? ?? '';
      debugPrint('[WS] event_type=$eventType');

      switch (eventType) {
        case 'im.message.receive_v1':
        case 'cofly.message.sync_v1':
          _handleMessageReceive(evt);
          break;
        case 'im.message.update_v1':
          _handleMessageUpdate(evt);
          break;
        case 'cofly.message.ack':
          debugPrint('[WS] ack: ${evt['event']}');
          break;
        default:
          debugPrint('[WS] unknown event_type: $eventType');
      }
    } catch (e) {
      debugPrint('[WS] _handleEventPayload error: $e');
    }
  }

  /// 处理收到新消息事件
  void _handleMessageReceive(Map<String, dynamic> evt) {
    try {
      final event = evt['event'] as Map<String, dynamic>;
      final msgData = event['message'] as Map<String, dynamic>;
      final sender = event['sender'] as Map<String, dynamic>?;

      final messageId = msgData['message_id'] as String? ?? '';
      final chatId = msgData['chat_id'] as String? ?? '';
      final messageType = msgData['message_type'] as String? ?? 'text';
      final contentStr = msgData['content'] as String? ?? '';

      debugPrint('[WS] receive_v1: msgId=$messageId, chatId=$chatId, type=$messageType');

      // Only binary media types skip content extraction; all others (text, post, interactive, etc.) get parsed
      const rawPassthroughTypes = {'image', 'file', 'audio', 'video'};
      final textContent = rawPassthroughTypes.contains(messageType)
          ? contentStr
          : _extractContent(contentStr);

      final senderId = sender?['sender_id']?['open_id'] as String? ?? '';

      // 使用服务器时间戳
      final header = evt['header'] as Map<String, dynamic>?;
      final createTime = header?['create_time'] as String?;
      final createdAt = createTime != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(createTime))
          : DateTime.now();

      final eventType = header?['event_type'] as String? ?? '';

      final message = Message(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        content: textContent,
        type: Message.parseMessageType(messageType),
        createdAt: createdAt,
        isFromBot: _botOpenId != null ? senderId == _botOpenId : true,
      );

      _messageStream.add((message, eventType));
    } catch (e) {
      debugPrint('[WS] _handleMessageReceive error: $e');
    }
  }

  /// 处理消息更新事件（流式输出）
  void _handleMessageUpdate(Map<String, dynamic> evt) {
    try {
      final event = evt['event'] as Map<String, dynamic>;
      final msgData = event['message'] as Map<String, dynamic>;

      final messageId = msgData['message_id'] as String? ?? '';
      final chatId = msgData['chat_id'] as String? ?? '';
      final contentStr = msgData['content'] as String? ?? '';

      debugPrint('[WS] update_v1: msgId=$messageId, chatId=$chatId');

      final messageType = msgData['message_type'] as String? ?? 'text';

      // Only binary media types skip content extraction; all others (text, post, interactive, etc.) get parsed
      const rawPassthroughTypes = {'image', 'file', 'audio', 'video'};
      final textContent = rawPassthroughTypes.contains(messageType)
          ? contentStr
          : _extractContent(contentStr);

      final senderId =
          event['sender']?['sender_id']?['open_id'] as String? ?? '';

      // 使用服务器时间戳
      final header = evt['header'] as Map<String, dynamic>?;
      final createTime = header?['create_time'] as String?;
      final createdAt = createTime != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(createTime))
          : DateTime.now();

      final message = Message(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        content: textContent,
        type: Message.parseMessageType(messageType),
        createdAt: createdAt,
        isFromBot: _botOpenId != null ? senderId == _botOpenId : true,
      );

      _messageStream.add((message, 'im.message.update_v1'));
    } catch (e) {
      debugPrint('[WS] _handleMessageUpdate error: $e');
    }
  }

  // ==================== Content Parsing ====================

  /// 从消息 content JSON 中提取文本内容（委托给 Message 共享方法）
  String _extractContent(String contentStr) {
    return Message.extractTextContent(contentStr);
  }

  // ==================== Heartbeat ====================

  /// 用 API URL 的 host 和 scheme 重建 WebSocket URL
  /// 服务端在反向代理后返回的 host 可能是内网 IP，不可直连
  String _correctWsScheme(String wsUrl, String apiUrl) {
    final apiUri = Uri.parse(apiUrl);
    final wsUri = Uri.parse(wsUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    // 保留服务端返回的 path 和 query，但用 API URL 的 host:port
    final corrected = wsUri.replace(
      scheme: scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : (scheme == 'wss' ? 443 : 80),
    );
    return corrected.toString();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) => _sendPing(),
    );
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _sendPing() {
    if (_channel == null) {
      debugPrint('[WS] sendPing skipped: no channel');
      return;
    }
    _pingSeqId++;
    debugPrint('[WS] sending ping seqId=$_pingSeqId');
    final pingBytes = makePingFrame(seqId: _pingSeqId);
    debugPrint('[WS] ping frame: ${pingBytes.length} bytes');
    _channel!.sink.add(pingBytes);
  }

  // ==================== Error Handling ====================

  void _handleError(error) {
    debugPrint('[WS] stream error: $error');
    _isConnected = false;
    _connectionStateStream.add(false);
    _scheduleReconnect();
  }

  void _handleDone() {
    debugPrint('[WS] stream done (connection closed), intentional=$_intentionalDisconnect');
    _isConnected = false;
    _connectionStateStream.add(false);
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) {
      debugPrint('[WS] reconnect already scheduled');
      return;
    }

    debugPrint('[WS] scheduling reconnect in 3s...');
    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () async {
        _reconnectTimer = null;
        try {
          await reconnect();
        } catch (e) {
          debugPrint('[WS] reconnect failed: $e');
          _scheduleReconnect();
        }
      },
    );
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ==================== Cleanup ====================

  void dispose() {
    disconnect();
    _messageStream.close();
    _connectionStateStream.close();
  }
}
