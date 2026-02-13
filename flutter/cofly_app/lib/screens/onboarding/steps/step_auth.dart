import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';

/// 步骤 2: 用户认证页（登录/注册双模式）
class StepAuth extends StatefulWidget {
  final String username;
  final Function({required String username, required String password})
      onCompleted;

  const StepAuth({
    super.key,
    this.username = '',
    required this.onCompleted,
  });

  @override
  State<StepAuth> createState() => _StepAuthState();
}

class _StepAuthState extends State<StepAuth> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _isRegisterMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.username;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
    });
  }

  /// 登录流程
  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = StorageService();
      await storage.init();

      final apiUrl = storage.getApiUrl();
      if (apiUrl.isEmpty) {
        throw Exception('请先配置 API 地址');
      }

      ApiService().init();

      final loginResponse = await ApiService().login(
        username: username,
        password: password,
      );

      if (loginResponse.success && loginResponse.token != null) {
        await storage.setUsername(username);
        await storage.setPassword(password);
        widget.onCompleted(username: username, password: password);
        return;
      }

      setState(() {
        _errorMessage = loginResponse.message ?? '登录失败';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        if (e is ApiException) {
          _errorMessage = e.message;
        } else {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        _isLoading = false;
      });
    }
  }

  /// 注册流程：注册成功后自动登录
  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final token = _tokenController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = StorageService();
      await storage.init();

      final apiUrl = storage.getApiUrl();
      if (apiUrl.isEmpty) {
        throw Exception('请先配置 API 地址');
      }

      ApiService().init();

      // 1. 注册
      final registerResponse = await ApiService().register(
        username: username,
        password: password,
        registrationToken: token.isEmpty ? null : token,
      );

      if (!registerResponse.success) {
        setState(() {
          _errorMessage = registerResponse.message ?? '注册失败';
          _isLoading = false;
        });
        return;
      }

      // 2. 注册成功，自动登录
      final loginResponse = await ApiService().login(
        username: username,
        password: password,
      );

      if (loginResponse.success && loginResponse.token != null) {
        await storage.setUsername(username);
        await storage.setPassword(password);
        widget.onCompleted(username: username, password: password);
        return;
      }

      setState(() {
        _errorMessage = loginResponse.message ?? '注册成功但登录失败，请切换到登录页重试';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        if (e is ApiException) {
          _errorMessage = e.message;
        } else {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Text(
            _isRegisterMode ? '用户注册' : '用户登录',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 副标题
          Text(
            _isRegisterMode ? '输入信息创建新账户' : '输入用户名和密码登录',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // 错误提示
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (_errorMessage != null) const SizedBox(height: 16),

          // 表单
          Form(
            key: _formKey,
            child: Column(
              children: [
                // 用户名输入框
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    hintText: '输入用户名',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入用户名';
                    }
                    if (value.trim().length < 3) {
                      return '用户名至少3个字符';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 密码输入框
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '输入密码',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: !_passwordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (value.length < 4) {
                      return '密码至少4个字符';
                    }
                    return null;
                  },
                  textInputAction: _isRegisterMode
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: _isRegisterMode ? null : (_) => _submitLogin(),
                ),

                // 注册令牌输入框（仅注册模式）
                if (_isRegisterMode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: '注册令牌',
                      hintText: '输入注册令牌',
                      prefixIcon: Icon(Icons.vpn_key),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入注册令牌';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitRegister(),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),

          // 提交按钮
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : (_isRegisterMode ? _submitRegister : _submitLogin),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isRegisterMode ? '注册' : '登录'),
          ),
          const SizedBox(height: 12),

          // 切换登录/注册
          TextButton(
            onPressed: _isLoading ? null : _toggleMode,
            child: Text(
              _isRegisterMode ? '已有账户？去登录' : '没有账户？去注册',
            ),
          ),
        ],
      ),
    );
  }
}
