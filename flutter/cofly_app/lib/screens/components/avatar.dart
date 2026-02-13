import 'dart:io';

import 'package:flutter/material.dart';

/// 头像组件
class Avatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool isDefault;

  const Avatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.isDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final isNetwork = imageUrl!.startsWith('http');
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: isNetwork
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : Image.file(
                File(imageUrl!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final initials = _getInitials();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColorFromName(),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: initials.isEmpty
          ? Icon(
              Icons.person,
              size: size * 0.6,
              color: Colors.white,
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  String _getInitials() {
    if (name == null || name!.isEmpty) return '';

    final parts = name!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name!.length >= 2) {
      return name!.substring(0, 2).toUpperCase();
    } else {
      return name!.toUpperCase();
    }
  }

  Color _getColorFromName() {
    if (name == null || name!.isEmpty) return Colors.blue;

    // 根据名字生成固定的颜色
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.red,
      Colors.cyan,
    ];

    final index = name!.codeUnitAt(0) % colors.length;
    return colors[index];
  }
}

/// Bot 头像组件
class BotAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const BotAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final isNetwork = imageUrl!.startsWith('http');
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: isNetwork
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : Image.file(
                File(imageUrl!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              ),
      );
    }

    final fallback = 'https://ui-avatars.com/api/?name=Bot&background=random';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        fallback,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        Icons.android,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}

/// 用户头像组件
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final isNetwork = imageUrl!.startsWith('http');
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: isNetwork
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : Image.file(
                File(imageUrl!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              ),
      );
    }

    final fallback = 'https://ui-avatars.com/api/?name=User&background=random';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        fallback,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}
