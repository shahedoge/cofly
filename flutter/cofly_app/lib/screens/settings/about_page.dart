import 'package:flutter/material.dart';

/// 关于页面
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用图标和名称
          const Column(
            children: [
              Icon(Icons.chat_bubble, size: 80, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Cofly',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('版本 1.0.0', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 32),

          // 应用介绍
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '关于 Cofly',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cofly 是一个智能聊天应用，连接 Cofly FastAPI 后端，提供实时消息收发、用户认证和配置管理功能。',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 功能特性
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '功能特性',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(context, Icons.message, '实时消息收发'),
                  _buildFeatureItem(context, Icons.security, '用户认证'),
                  _buildFeatureItem(context, Icons.settings, '个性化配置'),
                  _buildFeatureItem(context, Icons.palette, 'Material You 主题'),
                  _buildFeatureItem(context, Icons.offline_bolt, '离线消息缓存'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 开发者信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '开发者',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('ShaheDoge and Claude Code'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 开源协议
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '开源协议',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '本项目基于 GNU General Public License v3.0 许可证开源。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // TODO: 显示完整许可证
                    },
                    child: const Text('查看完整许可证'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 更新日志入口
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('更新日志'),
            subtitle: const Text('查看版本更新历史'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showChangelogDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
    );
  }

  void _showChangelogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新日志'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('v0.0.1', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• 首次发布'),
              Text('• 实时消息收发'),
              Text('• 用户认证系统'),
              Text('• 聊天记录本地缓存'),
              Text('• Material You 主题支持'),
              SizedBox(height: 16),
              Text('敬请期待更多功能更新！', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
