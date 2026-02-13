import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// 认证状态
enum AuthState {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

/// 认证服务
class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Dependencies
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  // Auth state
  AuthState _authState = AuthState.unauthenticated;
  String? _errorMessage;

  // Getters
  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  String? get username => _storage.getUsername();

  // ==================== Authentication ====================

  /// 用户认证（登录/自动注册）
  /// token endpoint 会自动注册不存在的用户
  Future<AuthResult> registerOrLogin({
    required String username,
    required String password,
  }) async {
    _authState = AuthState.authenticating;
    _errorMessage = null;

    try {
      final loginResponse = await _api.login(
        username: username,
        password: password,
      );

      if (loginResponse.success && loginResponse.token != null) {
        // 认证成功，保存凭证
        await _storage.setUsername(username);
        await _storage.setPassword(password);

        _authState = AuthState.authenticated;
        return AuthResult.success(
          user: User(
            id: username,
            username: username,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        // 认证失败
        final msg = loginResponse.message?.toLowerCase() ?? '';
        if (msg.contains('invalid') || msg.contains('credential') || msg.contains('密码')) {
          _errorMessage = '密码错误，请重新输入';
        } else {
          _errorMessage = loginResponse.message ?? '认证失败';
        }
        _authState = AuthState.error;
        return AuthResult.failure(message: _errorMessage!);
      }
    } on ApiException catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.message;
      return AuthResult.failure(message: _errorMessage!);
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString();
      return AuthResult.failure(message: _errorMessage!);
    }
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final username = _storage.getUsername();
    final password = await _storage.getPassword();

    return username != null &&
        username.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  /// 获取当前用户信息
  Future<User?> getCurrentUser() async {
    final username = _storage.getUsername();
    if (username == null) return null;

    return User(
      id: username,
      username: username,
      avatar: _storage.getUserAvatar(),
      createdAt: DateTime.now(),
    );
  }

  /// 更新用户信息
  Future<void> updateUser({
    String? avatar,
    String? password,
  }) async {
    if (avatar != null) {
      await _storage.setUserAvatar(avatar);
    }

    if (password != null && password.isNotEmpty) {
      await _storage.setPassword(password);
    }
  }

  /// 更新 Bot 配置
  Future<void> updateBotConfig({
    String? avatar,
    String? name,
  }) async {
    if (avatar != null) {
      await _storage.setBotAvatar(avatar);
    }

    if (name != null) {
      await _storage.setBotName(name);
    }
  }

  /// 退出登录
  Future<void> logout() async {
    // 清除本地存储的认证信息
    await _storage.setUsername('');
    await _storage.setPassword('');

    _authState = AuthState.unauthenticated;
    _errorMessage = null;
  }

  /// 清除所有数据并退出
  Future<void> clearAllDataAndLogout() async {
    await _storage.clearAllData();
    _authState = AuthState.unauthenticated;
    _errorMessage = null;
  }

  /// 验证 API 连通性
  Future<bool> verifyApiConnection() async {
    return await _api.verifyApiConnection();
  }
}

/// 认证结果
class AuthResult {
  final bool success;
  final User? user;
  final String? message;

  AuthResult({
    required this.success,
    this.user,
    this.message,
  });

  factory AuthResult.success({User? user}) {
    return AuthResult(
      success: true,
      user: user,
    );
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult(
      success: false,
      message: message,
    );
  }
}
