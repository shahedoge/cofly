import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 步骤 4: Bot 头像页
class StepBotAvatar extends StatefulWidget {
  final String initialAvatar;
  final Function(String?) onSelected;

  const StepBotAvatar({
    super.key,
    this.initialAvatar = '',
    required this.onSelected,
  });

  @override
  State<StepBotAvatar> createState() => _StepBotAvatarState();
}

class _StepBotAvatarState extends State<StepBotAvatar> {
  String? _avatar;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _avatar = widget.initialAvatar.isNotEmpty ? widget.initialAvatar : null;
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        // Copy to persistent app directory
        final appDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(appDir.path, 'avatars'));
        if (!avatarDir.existsSync()) {
          avatarDir.createSync(recursive: true);
        }
        final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
        final destPath = p.join(avatarDir.path, 'bot_avatar$ext');
        await File(image.path).copy(destPath);

        setState(() {
          _avatar = destPath;
        });
      }
    } catch (e) {
      _showError('选择图片失败');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            '设置 Bot 头像',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 副标题
          Text(
            '选择一个 Bot 头像，或者使用默认头像',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // 头像显示
          Center(
            child: Column(
              children: [
                // 大头像
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _avatar != null && _avatar!.startsWith('http')
                        ? Image.network(
                            _avatar!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.android,
                                size: 60,
                                color: Colors.grey,
                              );
                            },
                          )
                        : _avatar != null
                            ? Image.file(
                                File(_avatar!),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.purple,
                                child: const Icon(
                                  Icons.android,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 24),

                // 按钮组
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickImage,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library),
                      label: const Text('更换头像'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          // 跳过按钮 (使用默认)
          TextButton(
            onPressed: () {
              widget.onSelected(null);
            },
            child: const Text('使用默认头像'),
          ),
          const SizedBox(height: 8),

          // 下一步按钮
          ElevatedButton(
            onPressed: () {
              widget.onSelected(_avatar);
            },
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }
}
