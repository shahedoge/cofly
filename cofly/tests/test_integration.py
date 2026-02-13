#!/usr/bin/env python3
"""
Cofly 集成测试脚本

模拟普通用户发消息给 bot，验证 cofly 能正确转发给 clawdbot，
并能正确接收 clawdbot 的回复。

前置条件：
  1. cofly 已启动: cd cofly && uvicorn main:app --host 0.0.0.0 --port 8000
  2. clawdbot 已连接 cofly（domain 配置为 http://localhost:8000）

使用方式：
    python tests/test_integration.py [--base-url http://localhost:8000] [--timeout 60]
"""

import argparse
import json
import sys
import os
import time
import threading
import asyncio

import requests
import websockets

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from proto import make_frame, parse_frame, get_header

BOT_USERNAME = "<your bot username>"
TESTER_USERNAME = "<your tester username>"
TESTER_PASSWORD = "<your tester password>"


class CoflyClient:
    def __init__(self, base_url: str):
        self.base = base_url.rstrip("/")
        self.session = requests.Session()

    def _request(self, method, path, **kwargs):
        url = f"{self.base}{path}"
        try:
            r = self.session.request(method, url, **kwargs)
        except requests.ConnectionError:
            print(f"\n  错误：无法连接 {self.base}")
            print("  请确认 cofly 已启动")
            sys.exit(1)
        if not r.text:
            print(f"\n  错误：{method} {path} 返回空响应 (HTTP {r.status_code})")
            sys.exit(1)
        return r.json()

    def get_token(self, username, password):
        body = self._request("POST",
            "/open-apis/auth/v3/tenant_access_token/internal",
            json={"app_id": username, "app_secret": password},
        )
        assert body["code"] == 0, f"get_token failed: {body}"
        return body["tenant_access_token"]

    def lookup_user(self, username):
        """通过 username 查询用户 open_id"""
        body = self._request("GET", f"/cofly/users/{username}")
        if body["code"] != 0:
            return None
        return body["data"]["user"]["open_id"]

    def send_message(self, token, receive_id, text):
        body = self._request("POST",
            "/open-apis/im/v1/messages",
            params={"receive_id_type": "open_id"},
            json={
                "receive_id": receive_id,
                "msg_type": "text",
                "content": json.dumps({"text": text}),
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert body["code"] == 0, f"send_message failed: {body}"
        return body["data"]


async def ws_listen(ws_url, token, events, stop_event, timeout):
    """连接 WS，监听 im.message.receive_v1 事件"""
    uri = ws_url.replace("http://", "ws://").replace("https://", "wss://")
    uri = f"{uri}/ws?token={token}&device_id=test&service_id=1"

    async with websockets.connect(uri) as ws:
        ping = make_frame(seq_id=1, method=0, headers={"type": "ping"})
        await ws.send(ping)
        pong = await ws.recv()
        frame = parse_frame(pong)
        assert get_header(frame, "type") == "pong", "WS ping/pong 失败"
        print("  [WS] 连接成功，ping/pong 正常")
        stop_event._ws_ready = True

        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                raw = await asyncio.wait_for(
                    ws.recv(), timeout=min(2.0, deadline - time.time())
                )
            except asyncio.TimeoutError:
                continue
            except websockets.ConnectionClosed:
                break

            frame = parse_frame(raw)
            if frame.method == 1:
                evt = json.loads(frame.payload)
                event_type = evt.get("header", {}).get("event_type", "")
                print(f"  [WS] 收到事件: {event_type}")
                if event_type == "im.message.receive_v1":
                    events.append(evt)
                    break


def run_test(base_url: str, timeout: int):
    client = CoflyClient(base_url)

    # 1. 查询 bot 的 user_id（bot 由 clawdbot 自动注册）
    print("[1/4] 查询 bot user_id...")
    bot_id = client.lookup_user(BOT_USERNAME)
    if not bot_id:
        print(f"  bot 用户 '{BOT_USERNAME}' 不存在。请确认 clawdbot 已连接 cofly。")
        return False
    print(f"  bot_id={bot_id}")

    # 2. tester 登录 + 连 WS
    print("[2/4] tester 登录并连接 WS...")
    tester_token = client.get_token(TESTER_USERNAME, TESTER_PASSWORD)

    events = []
    stop_event = threading.Event()
    stop_event._ws_ready = False

    def _run_ws():
        asyncio.run(ws_listen(base_url, tester_token, events, stop_event, timeout))

    ws_thread = threading.Thread(target=_run_ws, daemon=True)
    ws_thread.start()

    for _ in range(50):
        if getattr(stop_event, "_ws_ready", False):
            break
        time.sleep(0.1)
    else:
        print("  WS 连接超时")
        return False

    # 3. 发消息给 bot
    print("[3/4] 发消息给 bot...")
    test_text = f"hello from integration test ({int(time.time())})"
    data = client.send_message(tester_token, bot_id, test_text)
    print(f"  消息已发送: {data['message_id']}")
    print(f"  等待 clawdbot 回复（最多 {timeout}s）...")
    ws_thread.join(timeout=timeout)

    if not events:
        print("  超时：未收到回复事件")
        return False

    # 4. 验证回复
    print("[4/4] 收到回复:")
    msg = events[0]["event"]["message"]
    try:
        content = json.loads(msg["content"])
        print(f"  {content.get('text', '')[:300]}")
    except json.JSONDecodeError:
        print(f"  (raw) {msg['content'][:300]}")

    print("\n=== 集成测试通过 ===")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cofly 集成测试")
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument("--timeout", type=int, default=60,
                        help="等待 clawdbot 回复的超时秒数")
    args = parser.parse_args()

    success = run_test(args.base_url, args.timeout)
    sys.exit(0 if success else 1)
