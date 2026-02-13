"""
Cofly 端到端测试脚本

测试完整链路：注册 → 鉴权 → WebSocket 连接 → 发消息 → WS 收事件 → 回复 → 查询

使用方式：
    cd cofly && python -m pytest tests/test_e2e.py -v

依赖：
    pip install pytest pytest-asyncio httpx
"""

import sys
import os
import json
import threading
import time

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from starlette.testclient import TestClient

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from database import engine, Base
from main import app
from proto import make_frame, parse_frame, get_header
from ws_manager import ws_manager


# ── Fixtures ──


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    ws_manager.connections.clear()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


# ── Async helpers (for httpx tests) ──


async def register(c, username, password, display_name=""):
    r = await c.post("/cofly/register", json={
        "username": username, "password": password,
        "display_name": display_name or username,
    })
    assert r.json()["code"] == 0
    return r.json()["data"]["user_id"]


async def get_token(c, username, password):
    r = await c.post("/open-apis/auth/v3/tenant_access_token/internal",
                     json={"app_id": username, "app_secret": password})
    assert r.json()["code"] == 0
    return r.json()["tenant_access_token"]


def auth_h(token):
    return {"Authorization": f"Bearer {token}"}


# ── Sync helpers (for Starlette TestClient / WS tests) ──


def register_sync(sc, username, password, display_name=""):
    r = sc.post("/cofly/register", json={
        "username": username, "password": password,
        "display_name": display_name or username,
    })
    assert r.json()["code"] == 0
    return r.json()["data"]["user_id"]


def token_sync(sc, username, password):
    r = sc.post("/open-apis/auth/v3/tenant_access_token/internal",
                json={"app_id": username, "app_secret": password})
    assert r.json()["code"] == 0
    return r.json()["tenant_access_token"]


# ═══════════════════════════════════════
# 1. 注册与鉴权
# ═══════════════════════════════════════


@pytest.mark.asyncio
async def test_register(client):
    uid = await register(client, "alice", "123", "Alice")
    assert uid

    # 重复注册应失败
    r = await client.post("/cofly/register", json={
        "username": "alice", "password": "123", "display_name": "Alice",
    })
    assert r.json()["code"] == 1


@pytest.mark.asyncio
async def test_token_and_wrong_password(client):
    await register(client, "alice", "123")
    tok = await get_token(client, "alice", "123")
    assert len(tok) > 0

    r = await client.post("/open-apis/auth/v3/tenant_access_token/internal",
                          json={"app_id": "alice", "app_secret": "wrong"})
    assert r.json()["code"] == 1


@pytest.mark.asyncio
async def test_no_token_returns_401(client):
    r = await client.get("/open-apis/im/v1/chats")
    assert r.status_code == 401


# ═══════════════════════════════════════
# 2. 消息收发
# ═══════════════════════════════════════


@pytest.mark.asyncio
async def test_send_creates_p2p_chat(client):
    alice_id = await register(client, "alice", "123")
    bob_id = await register(client, "bob", "456")
    tok = await get_token(client, "alice", "123")

    r = await client.post(
        "/open-apis/im/v1/messages?receive_id_type=open_id",
        json={"receive_id": bob_id, "msg_type": "text",
              "content": '{"text":"hi"}'},
        headers=auth_h(tok),
    )
    d = r.json()
    assert d["code"] == 0
    assert d["data"]["message_id"]
    assert d["data"]["chat_id"]

    # 会话列表
    r = await client.get("/open-apis/im/v1/chats", headers=auth_h(tok))
    items = r.json()["data"]["items"]
    assert len(items) == 1
    assert items[0]["chat_type"] == "p2p"


@pytest.mark.asyncio
async def test_send_via_chat_id(client):
    await register(client, "alice", "123")
    bob_id = await register(client, "bob", "456")
    tok = await get_token(client, "alice", "123")

    r = await client.post(
        "/open-apis/im/v1/messages?receive_id_type=open_id",
        json={"receive_id": bob_id, "msg_type": "text",
              "content": '{"text":"1"}'},
        headers=auth_h(tok),
    )
    chat_id = r.json()["data"]["chat_id"]

    r = await client.post(
        "/open-apis/im/v1/messages?receive_id_type=chat_id",
        json={"receive_id": chat_id, "msg_type": "text",
              "content": '{"text":"2"}'},
        headers=auth_h(tok),
    )
    assert r.json()["code"] == 0
    assert r.json()["data"]["chat_id"] == chat_id


@pytest.mark.asyncio
async def test_reply_sets_thread_ids(client):
    await register(client, "alice", "123")
    bob_id = await register(client, "bob", "456")
    a_tok = await get_token(client, "alice", "123")
    b_tok = await get_token(client, "bob", "456")

    r = await client.post(
        "/open-apis/im/v1/messages?receive_id_type=open_id",
        json={"receive_id": bob_id, "msg_type": "text",
              "content": '{"text":"hello"}'},
        headers=auth_h(a_tok),
    )
    msg_id = r.json()["data"]["message_id"]

    r = await client.post(
        f"/open-apis/im/v1/messages/{msg_id}/reply",
        json={"msg_type": "text", "content": '{"text":"hi back"}'},
        headers=auth_h(b_tok),
    )
    assert r.json()["code"] == 0
    reply_id = r.json()["data"]["message_id"]

    r = await client.get(f"/open-apis/im/v1/messages/{reply_id}",
                         headers=auth_h(b_tok))
    item = r.json()["data"]["items"][0]
    assert item["root_id"] == msg_id
    assert item["parent_id"] == msg_id


@pytest.mark.asyncio
async def test_get_message_detail(client):
    alice_id = await register(client, "alice", "123")
    bob_id = await register(client, "bob", "456")
    tok = await get_token(client, "alice", "123")

    r = await client.post(
        "/open-apis/im/v1/messages?receive_id_type=open_id",
        json={"receive_id": bob_id, "msg_type": "text",
              "content": '{"text":"test"}'},
        headers=auth_h(tok),
    )
    msg_id = r.json()["data"]["message_id"]

    r = await client.get(f"/open-apis/im/v1/messages/{msg_id}",
                         headers=auth_h(tok))
    d = r.json()
    assert d["code"] == 0
    item = d["data"]["items"][0]
    assert item["message_id"] == msg_id
    assert item["msg_type"] == "text"
    assert item["body"]["content"] == '{"text":"test"}'
    assert item["sender"]["id"] == alice_id


# ═══════════════════════════════════════
# 3. 联系人
# ═══════════════════════════════════════


@pytest.mark.asyncio
async def test_get_user_info(client):
    await register(client, "alice", "123", "Alice")
    bob_id = await register(client, "bob", "456", "Bob")
    tok = await get_token(client, "alice", "123")

    r = await client.get(f"/open-apis/contact/v3/users/{bob_id}",
                         headers=auth_h(tok))
    user = r.json()["data"]["user"]
    assert user["open_id"] == bob_id
    assert user["name"] == "Bob"
    assert user["en_name"] == "bob"


@pytest.mark.asyncio
async def test_ws_endpoint_discovery(client):
    r = await client.post("/callback/ws/endpoint")
    d = r.json()
    assert d["code"] == 0
    assert d["data"]["URL"] == "/ws"
    assert "PingInterval" in d["data"]["ClientConfig"]


# ═══════════════════════════════════════
# 4. WebSocket ping/pong
# ═══════════════════════════════════════


def test_ws_ping_pong():
    sc = TestClient(app)
    register_sync(sc, "alice", "123")
    tok = token_sync(sc, "alice", "123")

    with sc.websocket_connect(
        f"/ws?token={tok}&device_id=d1&service_id=1"
    ) as ws:
        ping = make_frame(seq_id=42, method=0,
                          headers={"type": "ping"})
        ws.send_bytes(ping)

        data = ws.receive_bytes()
        frame = parse_frame(data)
        assert get_header(frame, "type") == "pong"
        assert frame.SeqID == 42


# ═══════════════════════════════════════
# 5. 端到端：发消息 → WS 收事件 → 回复
# ═══════════════════════════════════════


def test_e2e_send_and_receive_via_ws():
    """
    alice 发消息 → bob 通过 WS 收到 im.message.receive_v1 事件 →
    bob 回复 → alice 查询回复
    """
    sc = TestClient(app)
    alice_id = register_sync(sc, "alice", "123", "Alice")
    bob_id = register_sync(sc, "bob", "456", "Bob")
    a_tok = token_sync(sc, "alice", "123")
    b_tok = token_sync(sc, "bob", "456")

    received = []

    def bob_listener():
        """bob 在后台线程监听 WS 事件"""
        with sc.websocket_connect(
            f"/ws?token={b_tok}&device_id=d1&service_id=1"
        ) as ws:
            # ping 确认连接
            ws.send_bytes(make_frame(
                seq_id=1, method=0, headers={"type": "ping"}))
            ws.receive_bytes()  # pong

            # 等待事件
            try:
                raw = ws.receive_bytes()
                frame = parse_frame(raw)
                if frame.method == 1:
                    received.append(json.loads(frame.payload))
            except Exception:
                pass

    t = threading.Thread(target=bob_listener)
    t.start()
    time.sleep(0.3)  # 等 bob WS 连接就绪

    # alice 发消息给 bob
    r = sc.post(
        "/open-apis/im/v1/messages?receive_id_type=open_id",
        json={"receive_id": bob_id, "msg_type": "text",
              "content": '{"text":"hey bob"}'},
        headers=auth_h(a_tok),
    )
    send_data = r.json()
    assert send_data["code"] == 0
    msg_id = send_data["data"]["message_id"]
    chat_id = send_data["data"]["chat_id"]

    t.join(timeout=5)

    # 验证 bob 收到的事件
    assert len(received) == 1
    evt = received[0]
    assert evt["header"]["event_type"] == "im.message.receive_v1"
    assert evt["header"]["app_id"] == "bob"
    assert evt["event"]["sender"]["sender_id"]["open_id"] == alice_id
    msg = evt["event"]["message"]
    assert msg["message_id"] == msg_id
    assert msg["chat_id"] == chat_id
    assert msg["chat_type"] == "p2p"
    assert msg["content"] == '{"text":"hey bob"}'

    # bob 回复
    r = sc.post(
        f"/open-apis/im/v1/messages/{msg_id}/reply",
        json={"msg_type": "text",
              "content": '{"text":"yo alice"}'},
        headers=auth_h(b_tok),
    )
    reply = r.json()
    assert reply["code"] == 0
    reply_id = reply["data"]["message_id"]

    # alice 查询回复
    r = sc.get(f"/open-apis/im/v1/messages/{reply_id}",
               headers=auth_h(a_tok))
    item = r.json()["data"]["items"][0]
    assert item["body"]["content"] == '{"text":"yo alice"}'
    assert item["root_id"] == msg_id
    assert item["parent_id"] == msg_id
