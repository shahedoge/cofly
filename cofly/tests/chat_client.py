#!/usr/bin/env python3
"""
双向长连接聊天客户端 — 与 clawdbot 实时对话

架构：
  主线程：读取 stdin，HTTP POST 发送消息
  后台线程：维持 WS 长连接，接收 receive_v1 / update_v1 事件

使用方式：
    python tests/chat_client.py [--base-url http://localhost:8000]

输入 /quit 或 Ctrl+C 退出。

!!!【先修改BOT_USERNAME、TESTER_USERNAME、TESTER_PASSWORD，然后再运行】
"""

import argparse
import asyncio
import json
import os
import sys
import threading
import time

import websockets

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from proto import make_frame, parse_frame, get_header

from test_clawdbot import CoflyClient, _extract_text

BOT_USERNAME = "<your bot username>"
TESTER_USERNAME = "<your tester username>"
TESTER_PASSWORD = "<your tester password>"


class WSListener:
    """后台 daemon 线程，维持 WS 长连接并打印收到的消息。"""

    def __init__(self, base_url: str, token: str):
        self.base_url = base_url
        self.token = token
        self._msg_content: dict[str, str] = {}  # message_id -> latest full text
        self._stop = False
        self._thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self._thread.start()

    def stop(self):
        self._stop = True

    def _run(self):
        asyncio.run(self._loop())

    async def _loop(self):
        uri = self.base_url.replace("http://", "ws://").replace("https://", "wss://")
        uri = f"{uri}/ws?token={self.token}&device_id=chat_client&service_id=1"

        while not self._stop:
            try:
                await self._connect(uri)
            except Exception as e:
                if self._stop:
                    break
                print(f"\n[WS] 连接断开: {type(e).__name__}: {e}，3 秒后重连...", flush=True)
                await asyncio.sleep(3)

    async def _connect(self, uri: str):
        async with websockets.connect(uri) as ws:
            # ping/pong 握手
            await ws.send(make_frame(seq_id=1, method=0, headers={"type": "ping"}))
            pong = await ws.recv()
            frame = parse_frame(pong)
            if get_header(frame, "type") != "pong":
                print("[WS] ping/pong 失败", flush=True)
                return
            print("[WS] 已连接", flush=True)

            while not self._stop:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
                except asyncio.TimeoutError:
                    continue
                except websockets.ConnectionClosed:
                    raise

                frame = parse_frame(raw)
                if frame.method != 1:
                    continue

                try:
                    evt = json.loads(frame.payload)
                except json.JSONDecodeError:
                    continue
                event_type = evt.get("header", {}).get("event_type", "")

                if event_type == "im.message.receive_v1":
                    self._handle_receive(evt)
                elif event_type == "im.message.update_v1":
                    self._handle_update(evt)
                elif event_type == "cofly.message.ack":
                    self._handle_ack(evt)

    def _handle_receive(self, evt: dict):
        msg = evt["event"]["message"]
        msg_id = msg["message_id"]
        content = json.loads(msg["content"])
        text = _extract_text(content)
        self._msg_content[msg_id] = text
        # 打印新消息（换行确保不和用户输入混在一起）
        print(f"\n[bot] {text}", flush=True)

    def _handle_update(self, evt: dict):
        msg = evt["event"]["message"]
        msg_id = msg["message_id"]
        content = json.loads(msg["content"])
        new_text = _extract_text(content)
        old_text = self._msg_content.get(msg_id, "")

        if new_text == old_text:
            return

        self._msg_content[msg_id] = new_text

        if new_text.startswith(old_text):
            # 增量：只打印新增部分（流式效果）
            delta = new_text[len(old_text):]
            print(delta, end="", flush=True)
        else:
            # 内容完全变了，重新打印
            print(f"\n[bot 编辑] {new_text}", flush=True)

    def _handle_ack(self, evt: dict):
        status = evt["event"]["status"]
        msg_id = evt["event"]["message_id"]
        if status == "delivered":
            print(f"  [✓ 已投递 bot]", flush=True)
        else:
            print(f"  [⏳ bot 离线，已排队等待]", flush=True)


def main():
    parser = argparse.ArgumentParser(description="双向长连接聊天客户端")
    parser.add_argument("--base-url", default="http://localhost:8000")
    args = parser.parse_args()

    client = CoflyClient(args.base_url)

    # 查找 bot
    bot_id = client.lookup_user(BOT_USERNAME)
    if not bot_id:
        print(f"bot '{BOT_USERNAME}' 不存在，尝试触发创建...")
        try:
            client.login(BOT_USERNAME, "placeholder")
        except AssertionError:
            pass
        bot_id = client.lookup_user(BOT_USERNAME)
    if not bot_id:
        print(f"错误：bot '{BOT_USERNAME}' 不存在。请确认 clawdbot 已连接 cofly。")
        sys.exit(1)

    # 登录 tester
    client.login(TESTER_USERNAME, TESTER_PASSWORD)
    print(f"已登录 {TESTER_USERNAME}，bot_id={bot_id}")

    # 启动 WS 监听
    listener = WSListener(args.base_url, client.token)
    listener.start()
    time.sleep(0.5)  # 等 WS 握手

    print("输入消息发送给 bot，/quit 退出\n")

    try:
        for line in sys.stdin:
            text = line.strip()
            if not text:
                continue
            if text == "/quit":
                break
            try:
                data = client.send_message(bot_id, text)
                print(f"  [已发送 {data['message_id']}]")
            except Exception as e:
                print(f"  [发送失败: {e}]")
    except KeyboardInterrupt:
        pass

    listener.stop()
    print("\n再见！")


if __name__ == "__main__":
    main()
