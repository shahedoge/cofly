import 'package:flutter/material.dart';

/// 步骤 5: Bot 名称页
class StepBotName extends StatefulWidget {
  final String initialName;
  final Function(String) onSubmitted;

  const StepBotName({
    super.key,
    this.initialName = '',
    required this.onSubmitted,
  });

  @override
  State<StepBotName> createState() => _StepBotNameState();
}

class _StepBotNameState extends State<StepBotName> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _controller.text.trim();
    widget.onSubmitted(name);
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
            '设置 Bot 名称',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 副标题
          Text(
            '给您的 Bot 起一个名字',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Bot 名称输入框
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Bot 名称',
                hintText: '输入 Bot 名称',
                prefixIcon: Icon(Icons.smart_toy),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入 Bot 名称';
                }
                if (value.trim().length < 1) {
                  return '名称至少1个字符';
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
                  '提示:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bot 名称将显示在聊天界面中，作为 Bot 的标识。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Spacer(),

          // 完成按钮
          ElevatedButton(
            onPressed: _submit,
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}
