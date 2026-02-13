import 'package:flutter/material.dart';

/// 步骤 1: API URL 输入页
class StepApiUrl extends StatefulWidget {
  final String initialUrl;
  final Function(String) onSubmitted;

  const StepApiUrl({
    super.key,
    this.initialUrl = '',
    required this.onSubmitted,
  });

  @override
  State<StepApiUrl> createState() => _StepApiUrlState();
}

class _StepApiUrlState extends State<StepApiUrl> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _validateUrl(String url) {
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final url = _controller.text.trim();
    if (!_validateUrl(url)) {
      _showError('请输入有效的 URL');
      return;
    }

    setState(() => _isLoading = true);

    // 模拟验证
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isLoading = false);
      widget.onSubmitted(url);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
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
            '输入 API 地址',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 副标题
          Text(
            '请输入 Cofly 服务器的 API 地址',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // URL 输入框
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: 'https://api.example.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入 API 地址';
                }
                if (!_validateUrl(value.trim())) {
                  return '请输入有效的 URL (http:// 或 https://)';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 24),

          // 示例
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '示例:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'http://localhost:8000\nhttps://api.cofly.example.com',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Spacer(),

          // 下一步按钮
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('下一步'),
          ),
        ],
      ),
    );
  }
}
