# Cofly Flutter App 项目文档

## 概述

Cofly 是一个基于 Flutter 的跨平台聊天客户端（v0.0.1），主要面向 macOS 桌面端，同时兼容 iOS/Android。它连接到一个模拟飞书/Lark Open API 接口的 Cofly FastAPI 后端，支持实时消息收发、流式输出、图片/文件发送、系统托盘、本地通知等功能。

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.10+ / Dart |
| 状态管理 | Provider (ChangeNotifier) |
| HTTP | Dio |
| WebSocket | web_socket_channel + 自定义 pbbp2 二进制帧协议 |
| 本地存储 | SharedPreferences (KV) + Hive (结构化) |
| 安全存储 | flutter_secure_storage |
| UI | Material 3 / Material You (dynamic_color) |
| Markdown | flutter_markdown |
| 桌面特性 | window_manager / tray_manager / flutter_local_notifications |
| 文件选择 | image_picker / file_picker |

## 项目结构

```
lib/
├── main.dart                          # 入口：初始化桌面窗口/托盘/通知，启动 CoflyApp
├── config/
│   └── theme.dart                     # Material 3 主题配置，预设颜色，默认头像
├── models/
│   ├── chat.dart                      # Chat、BotInfo、ChatListResponse
│   ├── config.dart                    # AppConfig 应用配置模型
│   ├── message.dart                   # Message、MessageType 枚举、请求/响应 DTO
│   └── user.dart                      # User、LoginResponse、RegisterResponse
├── providers/
│   ├── auth_provider.dart             # 认证状态机
│   ├── chat_provider.dart             # 聊天核心：消息管理、发送、上传、通知
│   └── theme_provider.dart            # 主题模式与颜色管理
├── screens/
│   ├── chat/
│   │   ├── chat_page.dart             # 聊天主页面，接入图片/文件选择器
│   │   ├── chat_list.dart             # 消息列表 ListView + 打字指示器 + 空状态
│   │   ├── input_bar.dart             # 输入栏：附件按钮、文本框、上传进度、发送
│   │   └── message_bubble.dart        # 消息气泡：文本/Markdown/图片/文件渲染
│   ├── components/
│   │   ├── avatar.dart                # Avatar / BotAvatar / UserAvatar 组件
│   │   └── menu_button.dart           # 菜单按钮、搜索对话框等通用组件
│   ├── onboarding/
│   │   ├── onboarding_page.dart       # 引导页 PageView（6 步）
│   │   └── steps/                     # 各引导步骤：API URL、认证、头像、Bot 配置
│   └── settings/
│       ├── settings_page.dart         # 设置页：服务器/用户/Bot/外观/数据
│       └── about_page.dart            # 关于页：版本、功能列表、许可证
├── services/
│   ├── api_service.dart               # HTTP 客户端（Dio 单例），所有 REST API
│   ├── auth_service.dart              # 认证逻辑层
│   ├── ws_service.dart                # WebSocket 客户端（pbbp2 协议）
│   ├── storage_service.dart           # 本地持久化（SharedPreferences + Hive）
│   ├── notification_service.dart      # 本地推送通知
│   └── tray_service.dart              # macOS 系统托盘
└── utils/
    ├── constants.dart                 # 存储 key、缓存时长等常量
    ├── pbbp2.dart                     # pbbp2 protobuf 二进制帧编解码
    └── platform_helper.dart           # 平台判断（isDesktop / isMobile）
```

## 架构设计

```
┌─────────────────────────────────────────────────┐
│                   Screens (UI)                  │
│  ChatPage / InputBar / MessageBubble / Settings │
└──────────────────────┬──────────────────────────┘
                       │ watch / read
┌──────────────────────▼──────────────────────────┐
│               Providers (State)                 │
│    ChatProvider / AuthProvider / ThemeProvider   │
└──────────────────────┬──────────────────────────┘
                       │ call
┌──────────────────────▼──────────────────────────┐
│               Services (I/O)                    │
│  ApiService / WsService / StorageService / ...  │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│             Models (Data)                       │
│  Message / Chat / User / AppConfig              │
└─────────────────────────────────────────────────┘
```

- UI 层通过 `context.watch<Provider>()` 监听状态变化，通过 `context.read<Provider>()` 调用方法
- Provider 层持有业务逻辑，调用 Service 层完成 I/O
- Service 层均为单例，负责网络请求、WebSocket 通信、本地存储
- Model 层提供双重序列化：API JSON 格式 + Hive 本地存储格式

## 核心流程

### 启动流程

```
main() → 初始化桌面窗口/托盘/通知 → CoflyApp
  → SplashPage → 检查 isFirstLaunch?
    → 是 → /onboarding（6 步引导）
    → 否 → 检查 isAuthenticated?
      → 是 → /chat
      → 否 → /onboarding
```

### 消息收发流程

```
发送文本：
  InputBar.onSend → ChatProvider.sendMessage()
    → 创建本地 Message → 保存到 Hive → ApiService.sendMessage()
    → 设置 isWaitingReply = true

发送图片：
  InputBar "+" → 选择图片 → ChatProvider.sendImageMessage()
    → 创建本地预览 Message(content=本地路径) → ApiService.uploadImage()
    → 获取 image_key → 更新本地 Message → ApiService.sendMessage(type=image)

发送文件：
  InputBar "+" → 选择文件 → ChatProvider.sendFileMessage()
    → 创建本地 Message(content=JSON{file_name,local_path})
    → ApiService.uploadFile() → 获取 file_key
    → 更新本地 Message → ApiService.sendMessage(type=file)

接收消息：
  WsService 收到二进制帧 → parseFrame() → _handleEventPayload()
    → im.message.receive_v1 / im.message.update_v1
    → 构造 Message → messageStream → ChatProvider._handleIncomingMessage()
    → 更新/插入消息列表 → 保存到 Hive → 可能触发本地通知
```

### WebSocket 连接

```
ChatProvider.connectToChat()
  → ApiService.login() 获取 tenant_access_token
  → ApiService.getWsEndpoint(token) 获取 ws:// URL
  → 修正 URL scheme（适配反向代理）
  → WebSocketChannel.connect()
  → 发送 ping 握手 → 启动 120s 心跳定时器
  → 监听二进制帧流（pbbp2 协议）
  → 断线自动重连（3s 延迟）
```

## API 端点

所有 HTTP 请求通过 `ApiService`（Dio）发出，自动携带 `Authorization: Bearer <token>`。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/open-apis/auth/v3/tenant_access_token/internal` | 登录获取 token |
| POST | `/cofly/register` | 注册 |
| GET | `/cofly/users/{username}` | 查询用户 open_id |
| POST | `/callback/ws/endpoint` | 获取 WebSocket 端点 URL |
| GET | `/open-apis/bot/v3/info` | 获取 Bot 信息 |
| POST | `/open-apis/im/v1/messages` | 发送消息 |
| GET | `/open-apis/im/v1/chats/{chatId}/messages` | 获取消息列表 |
| GET | `/open-apis/im/v1/chats` | 获取聊天列表 |
| POST | `/open-apis/im/v1/images` | 上传图片（multipart） |
| POST | `/open-apis/im/v1/files` | 上传文件（multipart） |

## 消息类型

`MessageType` 枚举定义了 5 种消息类型：

| 类型 | 发送编码 | 气泡渲染 |
|------|----------|----------|
| `text` | `{"text": "..."}` | 用户：纯文本气泡；Bot：Markdown 渲染 |
| `image` | `{"image_key": "..."}` | 本地路径 → Image.file；image_key → Image.network |
| `file` | `{"file_key": "...", "file_name": "..."}` | 文件图标 + 文件名卡片 |
| `audio` | — | 暂未实现 |
| `video` | — | 暂未实现 |

## 本地存储

采用双层存储策略：

- **SharedPreferences**：简单 KV 配置（API URL、用户名、主题色、暗色模式等）
- **Hive**：结构化数据
  - `config` box：完整 AppConfig
  - `messages` box：按日期分桶存储消息（key = `chatId_yyyy-MM-dd`）

消息默认缓存 2 天，可在设置中手动清理。

## 桌面特性（macOS）

- **窗口管理**：关闭窗口时隐藏而非退出（`windowManager.setPreventClose`）
- **系统托盘**：左键点击切换窗口显示/隐藏，右键菜单（显示/退出）
- **本地通知**：窗口未聚焦时收到 Bot 消息弹出系统通知，点击通知唤起窗口

## 引导流程（Onboarding）

首次启动进入 6 步引导 PageView：

1. 输入 API 服务器地址
2. 输入 App ID / App Secret 认证
3. 设置用户头像（可跳过）
4. 设置 Bot 头像（可跳过）
5. 输入 Bot 唯一标识（username）
6. 输入 Bot 显示名称

完成后持久化所有配置，跳转到聊天页面。

## pbbp2 协议

WebSocket 通信使用自定义二进制帧协议（对应后端 `pbbp2.proto`）：

- 帧结构：`seqId` / `logId` / `service` / `method` / `headers[]` / `payload`
- 编码：Varint + Length-delimited（类 Protobuf wire format）
- `method=0` + `header.type=ping` → 心跳 ping
- `method=1` → 事件推送，payload 为 JSON
- 事件类型：`im.message.receive_v1`（新消息）、`im.message.update_v1`（流式更新）、`cofly.message.ack`（确认）

## 开发信息

- 版本：0.0.1
- 许可证：GPLv3
- 开发者：ShaheDoge and Claude Code
