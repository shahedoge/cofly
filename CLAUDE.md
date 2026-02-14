# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cofly is a chat application system that provides a pluggable, publicly-accessible message forwarding interface for the OpenClaw/Claw ecosystem. It consists of two main components:

1. **Python FastAPI Backend** (`cofly/`) - REST API + WebSocket server
2. **Flutter Desktop Client** (`flutter/cofly_app/`) - Cross-platform client (macOS primary)

The app works with OpenClaw and the feishu (Lark/Feishu) plugin to provide multi-agent messaging capabilities.

## Common Commands

### Python API Backend

```bash
# Create and activate conda environment
conda create -n cofly python=3.13
conda activate cofly

# Install dependencies
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# Run the API server
uvicorn main:app --host 0.0.0.0 --port 8000

# Or with pm2 for production
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" --name "cofly_api"

# Run tests
pytest
```

### Flutter App

```bash
cd flutter/cofly_app

# Get dependencies
flutter pub get

# Run on macOS
flutter run -d macos

# Build macOS app
flutter build macos

# Build for iOS
flutter build ios

# Build for Android
flutter build apk
```

### Seed Bot Registration

After starting the API, configure bots by editing `cofly/seed_bot.py` to set bot app credentials, then run:
```bash
python cofly/seed_bot.py
```

## Architecture

### Backend (`cofly/`)

- **FastAPI** with **SQLite** (SQLAlchemy ORM)
- **WebSocket** for real-time messaging using custom **pbbp2 binary protocol**
- **JWT + bcrypt** for authentication
- Routers in `routers/` directory handle specific domains:
  - `auth_router.py` - Login, register, token management
  - `message_router.py` - Message CRUD
  - `chat_router.py` - Chat management
  - `contact_router.py` - Contact handling
  - `media_router.py` - File/image uploads
  - `reaction_router.py` - Message reactions
  - `ws_router.py` - WebSocket endpoint

### Frontend (`flutter/cofly_app/`)

Uses **Provider** pattern for state management with clean architecture:

```
Screens (UI) → Providers (State) → Services (I/O) → Models (Data)
```

Key services:
- `api_service.dart` - HTTP client (Dio singleton)
- `ws_service.dart` - WebSocket with pbbp2 binary protocol
- `storage_service.dart` - Local persistence (Hive + SharedPreferences)
- `notification_service.dart` - Native notifications
- `tray_service.dart` - macOS system tray integration

Desktop features use: `window_manager`, `tray_manager`, `flutter_local_notifications`

### Message Types

The app supports text, image, and file messages with Markdown rendering via `flutter_markdown`.

## Configuration

- Backend config in `cofly/config.py` - Set `SECRET_KEY` and `REGISTRATION_TOKEN` before first run
- App config in `flutter/cofly_app/lib/config/` - Theme and app settings
