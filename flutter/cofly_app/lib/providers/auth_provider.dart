import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

/// 认证状态提供者
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  // State
  AuthState _authState = AuthState.unauthenticated;
  User? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  AuthState get authState => _authState;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _authState == AuthState.authenticated &&
      _currentUser != null &&
      _currentUser!.username.isNotEmpty;

  // ==================== Authentication ====================

  /// 检查登录状态
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        _currentUser = user;
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 注册/登录
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.registerOrLogin(
        username: username,
        password: password,
      );

      if (result.success) {
        _currentUser = result.user;
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message;
        _authState = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.error;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _authState = AuthState.unauthenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除所有数据并退出
  Future<void> clearAllDataAndLogout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.clearAllDataAndLogout();
      _currentUser = null;
      _authState = AuthState.unauthenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
    }
  }

  /// 验证 API 连接
  Future<bool> verifyApiConnection() async {
    return await _authService.verifyApiConnection();
  }

  /// 更新用户信息
  Future<void> updateUser({
    String? avatar,
    String? password,
  }) async {
    await _authService.updateUser(avatar: avatar, password: password);

    if (avatar != null && _currentUser != null) {
      _currentUser = _currentUser!.copyWith(avatar: avatar);
      notifyListeners();
    }
  }

  /// 更新 Bot 配置
  Future<void> updateBotConfig({
    String? avatar,
    String? name,
  }) async {
    await _authService.updateBotConfig(avatar: avatar, name: name);
  }

  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
