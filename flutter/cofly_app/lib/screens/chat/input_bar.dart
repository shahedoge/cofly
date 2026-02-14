import 'package:flutter/material.dart';

/// 输入栏组件
class InputBar extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickFile;
  final bool isSending;
  final bool isConnected;
  final double? uploadProgress;

  const InputBar({
    super.key,
    required this.onSend,
    this.onPickImage,
    this.onPickFile,
    this.isSending = false,
    this.isConnected = true,
    this.uploadProgress,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;

  bool get _isUploading => widget.uploadProgress != null;
  bool get _inputDisabled =>
      !widget.isConnected || widget.isSending || _isUploading;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    widget.onSend(trimmedText);

    _controller.clear();
    setState(() => _isComposing = false);
  }

  void _handleTextChanged(String text) {
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('图片'),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onPickImage?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('文件'),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onPickFile?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上传进度条
        if (_isUploading)
          LinearProgressIndicator(
            value: widget.uploadProgress,
            minHeight: 3,
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // 连接状态指示器
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),

                // 附件按钮
                IconButton(
                  onPressed: _inputDisabled ? null : _showAttachmentMenu,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '发送图片或文件',
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),

                // 输入框
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText:
                            widget.isConnected ? '开始对话' : '重新连接中...',
                        hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      enabled: !_inputDisabled,
                      onSubmitted:
                          _isComposing ? _handleSubmitted : null,
                      onChanged: _handleTextChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 发送按钮
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _isComposing && !_inputDisabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isComposing && !_inputDisabled
                        ? () => _handleSubmitted(_controller.text)
                        : null,
                    icon: widget.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.send,
                            color: _isComposing
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    tooltip: '发送',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部安全区域
class KeyboardSafeArea extends StatelessWidget {
  final Widget child;

  const KeyboardSafeArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPadding = viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: child,
    );
  }
}
