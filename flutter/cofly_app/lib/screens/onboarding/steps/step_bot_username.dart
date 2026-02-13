import 'package:flutter/material.dart';

/// 步骤: Bot 唯一标识符页
class StepBotUsername extends StatefulWidget {
  final String initialUsername;
  final Function(String) onSubmitted;

  const StepBotUsername({
    super.key,
    this.initialUsername = '',
    required this.onSubmitted,
  });

  @override
  State<StepBotUsername> createState() => _StepBotUsernameState();
}

class _StepBotUsernameState extends State<StepBotUsername> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialUsername;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final username = _controller.text.trim();
    widget.onSubmitted(username);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '设置 Bot 唯一标识符',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            '输入 Bot 在后端的 username',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Bot Username',
                hintText: '例如: cli_a9f1ed06c1449bc7',
                prefixIcon: Icon(Icons.fingerprint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入 Bot 唯一标识符';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 24),

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
                  '提示:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bot 唯一标识符是 Bot 在后端系统中的 username，用于与 Bot 建立通信。'
                  '它通常类似于 cli_a9f1ed06c1449bc7 的格式。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Spacer(),

          ElevatedButton(onPressed: _submit, child: const Text('下一步')),
        ],
      ),
    );
  }
}
