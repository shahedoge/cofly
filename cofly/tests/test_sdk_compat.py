"""
协议兼容性测试 — 模拟飞书 SDK 的完整行为

验证 cofly 的接口格式是否与 @larksuiteoapi/node-sdk 的预期完全匹配。
不需要 clawdbot 运行，纯粹测试 cofly 的 API 兼容性。

使用方式：
    cd cofly && python -m pytest tests/test_sdk_compat.py -v
"""

import sys
import os
import json
import threading
import time

import pytest
from starlette.testclient import TestClient

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from database import engine, Base
from main import app
from proto import make_frame, parse_frame, get_header
from ws_manager import ws_manager

BOT_USERNAME = "<bot app id>"
BOT_PASSWORD = "<bot app secret key>"


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    ws_manager.connections.clear()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def sc():
    return TestClient(app)


def _setup_bot(sc):
    r = sc.post("/cofly/register", json={
        "username": BOT_USERNAME, "password": BOT_PASSWORD,
        "display_name": "Bot",
    })
    bot_id = r.json()["data"]["user_id"]
    r = sc.post("/open-apis/auth/v3/tenant_access_token/internal",
                json={"app_id": BOT_USERNAME, "app_secret": BOT_PASSWORD})
    return bot_id, r.json()["tenant_access_token"]


def _setup_user(sc, name="alice", pwd="123"):
    r = sc.post("/cofly/register", json={
        "username": name, "password": pwd, "display_name": name.title(),
    })
    uid = r.json()["data"]["user_id"]
    r = sc.post("/open-apis/auth/v3/tenant_access_token/internal",
                json={"app_id": name, "app_secret": pwd})
    return uid, r.json()["tenant_access_token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


# ═══════════════════════════════════════
# 1. Token response shape (SDK expects top-level fields)
# ═══════════════════════════════════════


def test_token_response_shape(sc):
    """
    SDK calls POST /open-apis/auth/v3/tenant_access_token/internal
    with {app_id, app_secret} and expects {code, tenant_access_token, expire}
    at TOP LEVEL — not nested inside data.
    """
    sc.post("/cofly/register", json={
        "username": BOT_USERNAME, "password": BOT_PASSWORD,
        "display_name": "Bot",
    })
    r = sc.post("/open-apis/auth/v3/tenant_access_token/internal",
                json={"app_id": BOT_USERNAME, "app_secret": BOT_PASSWORD})
    body = r.json()

    # Must be top-level keys, not nested in "data"
    assert "code" in body
    assert body["code"] == 0
    assert "tenant_access_token" in body
    assert isinstance(body["tenant_access_token"], str)
    assert len(body["tenant_access_token"]) > 0
    assert "expire" in body
    assert isinstance(body["expire"], int)
    assert body["expire"] > 0

    # SDK does NOT expect a "data" wrapper for this endpoint
    # The token must be directly at body["tenant_access_token"]
    assert body.get("data") is None or "tenant_access_token" not in body.get("data", {})


# ═══════════════════════════════════════
# 2. Bot info (probe.ts reads response.bot || response.data?.bot)
# ═══════════════════════════════════════


def test_bot_info(sc):
    """
    SDK calls GET /open-apis/bot/v3/info with Bearer token.
    Expects {code, bot: {bot_name, open_id}}.
    probe.ts reads response.bot || response.data?.bot
    """
    bot_id, token = _setup_bot(sc)
    r = sc.get("/open-apis/bot/v3/info", headers=_auth(token))
    body = r.json()

    assert body["code"] == 0
    # "bot" must be present (probe.ts checks response.bot first)
    assert "bot" in body
    bot = body["bot"]
    assert "bot_name" in bot
    assert "open_id" in bot
    assert bot["open_id"] == bot_id
    assert bot["bot_name"] == "Bot"


# ═══════════════════════════════════════
# 3. Contact user with user_id_type query param
# ═══════════════════════════════════════


def test_contact_user_with_user_id_type(sc):
    """
    SDK calls GET /open-apis/contact/v3/users/:user_id?user_id_type=open_id
    Expects {code, data: {user: {name, en_name, nickname, display_name, open_id}}}
    """
    bot_id, bot_token = _setup_bot(sc)
    alice_id, _ = _setup_user(sc, "alice", "123")

    r = sc.get(
        f"/open-apis/contact/v3/users/{alice_id}",
        params={"user_id_type": "open_id"},
        headers=_auth(bot_token),
    )
    body = r.json()

    assert body["code"] == 0
    assert "data" in body
    assert "user" in body["data"]

    user = body["data"]["user"]
    assert user["open_id"] == alice_id
    assert "name" in user
    assert "en_name" in user
    assert "nickname" in user
    # en_name should be the username
    assert user["en_name"] == "alice"


# ═══════════════════════════════════════
# 4. Message create response
# ═══════════════════════════════════════


def test_message_create_response(sc):
    """
    SDK calls POST /open-apis/im/v1/messages with params: {receive_id_type}
    and data: {receive_id, content, msg_type}.
    Expects {code, data: {message_id}}.
    """
    bot_id, bot_token = _setup_bot(sc)
    alice_id, _ = _setup_user(sc, "alice", "123")

    r = sc.post(
        "/open-apis/im/v1/messages",
        params={"receive_id_type": "open_id"},
        json={
            "receive_id": alice_id,
            "msg_type": "text",
            "content": '{"text":"hello from bot"}',
        },
        headers=_auth(bot_token),
    )
    body = r.json()

    assert body["code"] == 0
    assert "data" in body
    assert "message_id" in body["data"]
    assert isinstance(body["data"]["message_id"], str)
    assert len(body["data"]["message_id"]) > 0


# ═══════════════════════════════════════
# 5. Message reply response
# ═══════════════════════════════════════


def test_message_reply_response(sc):
    """
    SDK calls POST /open-apis/im/v1/messages/:id/reply
    with data: {content, msg_type}.
    Expects {code, data: {message_id}}.
    """
    bot_id, bot_token = _setup_bot(sc)
    alice_id, alice_token = _setup_user(sc, "alice", "123")

    # Alice sends a message to bot first
    r = sc.post(
        "/open-apis/im/v1/messages",
        params={"receive_id_type": "open_id"},
        json={
            "receive_id": bot_id,
            "msg_type": "text",
            "content": '{"text":"hi bot"}',
        },
        headers=_auth(alice_token),
    )
    original_msg_id = r.json()["data"]["message_id"]

    # Bot replies
    r = sc.post(
        f"/open-apis/im/v1/messages/{original_msg_id}/reply",
        json={
            "msg_type": "text",
            "content": '{"text":"hi alice"}',
        },
        headers=_auth(bot_token),
    )
    body = r.json()

    assert body["code"] == 0
    assert "data" in body
    assert "message_id" in body["data"]
    assert isinstance(body["data"]["message_id"], str)
    assert len(body["data"]["message_id"]) > 0
    # Reply message_id must differ from original
    assert body["data"]["message_id"] != original_msg_id


# ═══════════════════════════════════════
# 6. Message get response (items shape)
# ═══════════════════════════════════════


def test_message_get_response(sc):
    """
    SDK calls GET /open-apis/im/v1/messages/:id
    Expects {code, data: {items: [{message_id, chat_id, msg_type,
             body: {content}, sender: {id, id_type}, create_time}]}}
    """
    bot_id, bot_token = _setup_bot(sc)
    alice_id, _ = _setup_user(sc, "alice", "123")

    # Bot sends a message
    r = sc.post(
        "/open-apis/im/v1/messages",
        params={"receive_id_type": "open_id"},
        json={
            "receive_id": alice_id,
            "msg_type": "text",
            "content": '{"text":"sdk compat test"}',
        },
        headers=_auth(bot_token),
    )
    msg_id = r.json()["data"]["message_id"]

    # Fetch the message
    r = sc.get(
        f"/open-apis/im/v1/messages/{msg_id}",
        headers=_auth(bot_token),
    )
    body = r.json()

    assert body["code"] == 0
    assert "data" in body
    assert "items" in body["data"]
    assert isinstance(body["data"]["items"], list)
    assert len(body["data"]["items"]) >= 1

    item = body["data"]["items"][0]
    # All fields the SDK expects
    assert item["message_id"] == msg_id
    assert "chat_id" in item
    assert item["msg_type"] == "text"
    assert "body" in item
    assert item["body"]["content"] == '{"text":"sdk compat test"}'
    assert "sender" in item
    assert item["sender"]["id"] == bot_id
    assert item["sender"]["id_type"] == "open_id"
    assert "create_time" in item
    # create_time should be a numeric string (milliseconds)
    assert item["create_time"].isdigit()


# ═══════════════════════════════════════
# 7. WS endpoint response (ClientConfig shape)
# ═══════════════════════════════════════


def test_ws_endpoint_response(sc):
    """
    POST /callback/ws/endpoint
    Expects {code, data: {URL, ClientConfig: {ReconnectCount,
             ReconnectInterval, ReconnectNonce, PingInterval}}}
    """
    r = sc.post("/callback/ws/endpoint")
    body = r.json()

    assert body["code"] == 0
    assert "data" in body
    data = body["data"]
    assert "URL" in data
    assert isinstance(data["URL"], str)

    assert "ClientConfig" in data
    cfg = data["ClientConfig"]
    assert "ReconnectCount" in cfg
    assert "ReconnectInterval" in cfg
    assert "ReconnectNonce" in cfg
    assert "PingInterval" in cfg
    # All config values should be positive integers
    assert isinstance(cfg["ReconnectCount"], int) and cfg["ReconnectCount"] > 0
    assert isinstance(cfg["ReconnectInterval"], int) and cfg["ReconnectInterval"] > 0
    assert isinstance(cfg["ReconnectNonce"], int) and cfg["ReconnectNonce"] > 0
    assert isinstance(cfg["PingInterval"], int) and cfg["PingInterval"] > 0


# ═══════════════════════════════════════
# 8. WS event push format (im.message.receive_v1)
# ═══════════════════════════════════════


def test_ws_event_push_format():
    """
    Bob connects WS, alice sends a message to bob.
    Verify the pushed event JSON matches the im.message.receive_v1 schema exactly:
      schema, header.event_type, header.app_id,
      event.sender.sender_id.open_id, event.message fields.
    """
    sc = TestClient(app)
    alice_id, alice_token = _setup_user(sc, "alice", "123")
    bob_id, bob_token = _setup_user(sc, "bob", "456")

    received = []

    def bob_listener():
        with sc.websocket_connect(
            f"/ws?token={bob_token}&device_id=d1&service_id=1"
        ) as ws:
            # Ping to confirm connection
            ws.send_bytes(make_frame(
                seq_id=1, method=0, headers={"type": "ping"}))
            ws.receive_bytes()  # pong

            # Wait for event push
            try:
                raw = ws.receive_bytes()
                frame = parse_frame(raw)
                if frame.method == 1:
                    received.append(json.loads(frame.payload))
            except Exception:
                pass

    t = threading.Thread(target=bob_listener)
    t.start()
    time.sleep(0.3)  # Wait for bob's WS to be ready

    # Alice sends message to bob
    r = sc.post(
        "/open-apis/im/v1/messages?receive_id_type=open_id",
        json={
            "receive_id": bob_id,
            "msg_type": "text",
            "content": '{"text":"hey bob"}',
        },
        headers=_auth(alice_token),
    )
    assert r.json()["code"] == 0
    msg_id = r.json()["data"]["message_id"]
    chat_id = r.json()["data"]["chat_id"]

    t.join(timeout=5)

    # Verify event was received
    assert len(received) == 1
    evt = received[0]

    # Top-level schema field (Feishu SDK v2 format)
    assert evt["schema"] == "2.0"

    # header fields
    header = evt["header"]
    assert header["event_type"] == "im.message.receive_v1"
    assert header["app_id"] == "bob"
    assert "event_id" in header
    assert "create_time" in header
    assert "tenant_key" in header

    # event.sender
    sender = evt["event"]["sender"]
    assert sender["sender_id"]["open_id"] == alice_id
    assert sender["sender_id"]["user_id"] == alice_id
    assert sender["sender_id"]["union_id"] == alice_id
    assert sender["sender_type"] == "user"

    # event.message — all fields the SDK reads
    msg = evt["event"]["message"]
    assert msg["message_id"] == msg_id
    assert msg["chat_id"] == chat_id
    assert msg["chat_type"] == "p2p"
    assert msg["message_type"] == "text"
    assert msg["content"] == '{"text":"hey bob"}'
    assert "mentions" in msg
    assert isinstance(msg["mentions"], list)
