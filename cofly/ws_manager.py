import asyncio
import json
import logging
import time
import uuid
from typing import Dict

from fastapi import WebSocket

from proto import parse_frame, get_header, make_pong_frame, make_event_frame

logger = logging.getLogger("cofly.ws")


class WSManager:
    def __init__(self):
        # user_id -> WebSocket
        self.connections: Dict[str, WebSocket] = {}
        self._seq_counter = 0
        # user_id -> list of pending events (delivered when user connects)
        self._pending: Dict[str, list] = {}

    async def connect(self, user_id: str, ws: WebSocket):
        await ws.accept()
        self.connections[user_id] = ws
        logger.info("WS connected: user_id=%s (total: %d)", user_id, len(self.connections))
        # Flush any pending events
        pending = self._pending.pop(user_id, [])
        for event_json in pending:
            await self.push_event(user_id, event_json)

    def disconnect(self, user_id: str):
        self.connections.pop(user_id, None)
        logger.info("WS disconnected: user_id=%s (total: %d)", user_id, len(self.connections))

    def is_online(self, user_id: str) -> bool:
        return user_id in self.connections

    async def handle_frame(self, user_id: str, data: bytes):
        frame = parse_frame(data)
        frame_type = get_header(frame, "type")
        if frame_type == "ping":
            ws = self.connections.get(user_id)
            if ws:
                pong = make_pong_frame(frame)
                await ws.send_bytes(pong)

    async def push_event(self, target_user_id: str, event_json: dict) -> bool:
        """Push event to target user. Returns True if delivered immediately, False if queued."""
        ws = self.connections.get(target_user_id)
        if not ws:
            logger.info("push_event: user_id=%s NOT online, queuing. Online: %s",
                        target_user_id, list(self.connections.keys()))
            self._pending.setdefault(target_user_id, []).append(event_json)
            return False
        self._seq_counter += 1
        frame_bytes = make_event_frame(event_json, seq_id=self._seq_counter)
        try:
            await ws.send_bytes(frame_bytes)
            logger.info("push_event: sent to user_id=%s, event_type=%s",
                        target_user_id, event_json.get("header", {}).get("event_type"))
            return True
        except Exception as e:
            logger.error("push_event: failed for user_id=%s: %s", target_user_id, e)
            self.disconnect(target_user_id)
            return False


def build_message_event(
    sender_id: str,
    receiver_username: str,
    message_id: str,
    chat_id: str,
    chat_type: str,
    message_type: str,
    content: str,
    root_id: str = "",
    parent_id: str = "",
) -> dict:
    now_ms = str(int(time.time() * 1000))
    return {
        "schema": "2.0",
        "header": {
            "event_id": str(uuid.uuid4()),
            "event_type": "im.message.receive_v1",
            "create_time": now_ms,
            "token": "",
            "app_id": receiver_username,
            "tenant_key": "cofly",
        },
        "event": {
            "sender": {
                "sender_id": {
                    "open_id": sender_id,
                    "user_id": sender_id,
                    "union_id": sender_id,
                },
                "sender_type": "user",
                "tenant_key": "cofly",
            },
            "message": {
                "message_id": message_id,
                "root_id": root_id,
                "parent_id": parent_id,
                "chat_id": chat_id,
                "chat_type": chat_type,
                "message_type": message_type,
                "content": content,
                "mentions": [],
            },
        },
    }


def build_message_update_event(
    sender_id: str,
    receiver_username: str,
    message_id: str,
    chat_id: str,
    chat_type: str,
    message_type: str,
    content: str,
) -> dict:
    now_ms = str(int(time.time() * 1000))
    return {
        "schema": "2.0",
        "header": {
            "event_id": str(uuid.uuid4()),
            "event_type": "im.message.update_v1",
            "create_time": now_ms,
            "token": "",
            "app_id": receiver_username,
            "tenant_key": "cofly",
        },
        "event": {
            "sender": {
                "sender_id": {
                    "open_id": sender_id,
                    "user_id": sender_id,
                    "union_id": sender_id,
                },
                "sender_type": "user",
                "tenant_key": "cofly",
            },
            "message": {
                "message_id": message_id,
                "chat_id": chat_id,
                "chat_type": chat_type,
                "message_type": message_type,
                "content": content,
            },
        },
    }


def build_ack_event(
    message_id: str,
    chat_id: str,
    receiver_username: str,
    bot_delivered: bool,
) -> dict:
    now_ms = str(int(time.time() * 1000))
    return {
        "schema": "2.0",
        "header": {
            "event_id": str(uuid.uuid4()),
            "event_type": "cofly.message.ack",
            "create_time": now_ms,
            "token": "",
            "app_id": receiver_username,
            "tenant_key": "cofly",
        },
        "event": {
            "message_id": message_id,
            "chat_id": chat_id,
            "status": "delivered" if bot_delivered else "queued",
        },
    }


ws_manager = WSManager()
