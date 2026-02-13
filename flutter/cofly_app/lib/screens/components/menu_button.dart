import 'package:flutter/material.dart';

/// 菜单按钮组件
class MenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? iconColor;

  const MenuButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      color: iconColor ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}

/// 聊天页面 AppBar 菜单按钮
class ChatMenuButton extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onMorePressed;

  const ChatMenuButton({
    super.key,
    this.onMenuPressed,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 左侧菜单按钮
        MenuButton(
          onPressed: onMenuPressed,
          icon: Icons.menu,
          tooltip: '菜单',
        ),
        // 右侧更多按钮
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'search':
                _showSearchDialog(context);
                break;
              case 'clear':
                _showClearDialog(context);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 8),
                  Text('搜索'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 8),
                  Text('清空记录'),
                ],
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.more_vert),
          ),
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SearchDialog(),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现清空记录
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 搜索对话框
class SearchDialog extends StatefulWidget {
  SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索聊天记录',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // TODO: 实现搜索
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置页面菜单按钮
class SettingsMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SettingsMenuButton({
    super.key,
    this.onPressed,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onPressed,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }
}

/// 返回按钮
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back),
      tooltip: '返回',
    );
  }
}
