#!/usr/bin/env python3
"""
Cofly 全功能集成测试 — 与 openclaw clawdbot-feishu 插件交互

测试完整链路：
  1. 基础连通：tester 发消息给 bot → bot 通过 WS 回复
  2. 消息编辑：PATCH 更新已发送的消息
  3. 图片上传/下载
  4. 文件上传/下载 + 消息资源下载
  5. Reaction 添加/列出/删除
  6. 富文本消息（post 类型）

前置条件：
  1. cofly 已启动: cd cofly && uvicorn main:app --host 0.0.0.0 --port 8000
  2. openclaw 已启动且 clawdbot-feishu 插件已连接 cofly

使用方式：
    python tests/test_clawdbot.py [--base-url http://localhost:8000] [--timeout 120]
"""

import argparse
import json
import sys
import os
import time
import asyncio
import io

import requests
import websockets

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from proto import make_frame, parse_frame, get_header

BOT_USERNAME = "<your bot username>"
TESTER_USERNAME = "<your tester username>"
TESTER_PASSWORD = "<your tester password>"
TESTER_DISPLAY = "集成测试用户"


# ── HTTP 客户端封装 ──


class CoflyClient:
    def __init__(self, base_url: str):
        self.base = base_url.rstrip("/")
        self.session = requests.Session()
        self.token = None

    def _url(self, path):
        return f"{self.base}{path}"

    def _auth(self):
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    def _request(self, method, path, **kwargs):
        headers = kwargs.pop("headers", {})
        headers.update(self._auth())
        try:
            r = self.session.request(method, self._url(path), headers=headers, **kwargs)
        except requests.ConnectionError:
            print(f"\n  错误：无法连接 {self.base}")
            print("  请确认 cofly 已启动")
            sys.exit(1)
        if not r.text:
            print(f"\n  错误：{method} {path} 返回空响应 (HTTP {r.status_code})")
            sys.exit(1)
        return r

    def _json(self, method, path, **kwargs):
        return self._request(method, path, **kwargs).json()

    # ── Auth ──

    def login(self, username, password):
        body = self._json("POST",
            "/open-apis/auth/v3/tenant_access_token/internal",
            json={"app_id": username, "app_secret": password})
        assert body["code"] == 0, f"login failed: {body}"
        self.token = body["tenant_access_token"]
        return self.token

    def lookup_user(self, username):
        body = self._json("GET", f"/cofly/users/{username}")
        return body["data"]["user"]["open_id"] if body["code"] == 0 else None

    # ── Messages ──

    def send_message(self, receive_id, text, msg_type="text"):
        if msg_type == "text":
            content = json.dumps({"text": text})
        else:
            content = text  # caller provides raw JSON string
        body = self._json("POST", "/open-apis/im/v1/messages",
            params={"receive_id_type": "open_id"},
            json={"receive_id": receive_id, "msg_type": msg_type, "content": content})
        assert body["code"] == 0, f"send_message failed: {body}"
        return body["data"]

    def reply_message(self, message_id, text, msg_type="text"):
        if msg_type == "text":
            content = json.dumps({"text": text})
        else:
            content = text
        body = self._json("POST", f"/open-apis/im/v1/messages/{message_id}/reply",
            json={"msg_type": msg_type, "content": content})
        assert body["code"] == 0, f"reply_message failed: {body}"
        return body["data"]

    def get_message(self, message_id):
        body = self._json("GET", f"/open-apis/im/v1/messages/{message_id}")
        assert body["code"] == 0, f"get_message failed: {body}"
        return body["data"]["items"][0]

    def patch_message(self, message_id, text, msg_type="text"):
        if msg_type == "text":
            content = json.dumps({"text": text})
        else:
            content = text
        body = self._json("PATCH", f"/open-apis/im/v1/messages/{message_id}",
            json={"msg_type": msg_type, "content": content})
        assert body["code"] == 0, f"patch_message failed: {body}"
        return body["data"]

    # ── Media ──

    def upload_image(self, image_bytes, filename="test.png"):
        r = self._request("POST", "/open-apis/im/v1/images",
            files={"image": (filename, io.BytesIO(image_bytes), "image/png")},
            data={"image_type": "message"})
        body = r.json()
        assert body["code"] == 0, f"upload_image failed: {body}"
        return body["data"]["image_key"]

    def download_image(self, image_key):
        r = self._request("GET", f"/open-apis/im/v1/images/{image_key}")
        assert r.status_code == 200, f"download_image failed: HTTP {r.status_code}"
        return r.content

    def upload_file(self, file_bytes, file_name="test.txt", file_type="stream"):
        r = self._request("POST", "/open-apis/im/v1/files",
            files={"file": (file_name, io.BytesIO(file_bytes), "application/octet-stream")},
            data={"file_type": file_type, "file_name": file_name})
        body = r.json()
        assert body["code"] == 0, f"upload_file failed: {body}"
        return body["data"]["file_key"]

    def download_resource(self, message_id, file_key):
        r = self._request("GET",
            f"/open-apis/im/v1/messages/{message_id}/resources/{file_key}")
        assert r.status_code == 200, f"download_resource failed: HTTP {r.status_code}"
        return r.content

    # ── Reactions ──

    def add_reaction(self, message_id, emoji_type="THUMBSUP"):
        body = self._json("POST",
            f"/open-apis/im/v1/messages/{message_id}/reactions",
            json={"reaction_type": {"emoji_type": emoji_type}})
        assert body["code"] == 0, f"add_reaction failed: {body}"
        return body["data"]

    def list_reactions(self, message_id):
        body = self._json("GET",
            f"/open-apis/im/v1/messages/{message_id}/reactions")
        assert body["code"] == 0, f"list_reactions failed: {body}"
        return body["data"]

    def delete_reaction(self, message_id, reaction_id):
        body = self._json("DELETE",
            f"/open-apis/im/v1/messages/{message_id}/reactions/{reaction_id}")
        assert body["code"] == 0, f"delete_reaction failed: {body}"


# ── WebSocket 监听器 ──


async def ws_listen(ws_url, token, events, timeout, stop_event=None):
    """连接 WS，持续收集事件。

    stop_event: asyncio.Event，外部设置后退出循环。
    """
    uri = ws_url.replace("http://", "ws://").replace("https://", "wss://")
    uri = f"{uri}/ws?token={token}&device_id=test&service_id=1"

    async with websockets.connect(uri) as ws:
        # ping 确认连接
        await ws.send(make_frame(seq_id=1, method=0, headers={"type": "ping"}))
        pong = await ws.recv()
        frame = parse_frame(pong)
        assert get_header(frame, "type") == "pong", "WS ping/pong 失败"
        print("  [WS] 连接成功")

        deadline = time.time() + timeout
        while time.time() < deadline:
            if stop_event and stop_event.is_set():
                break
            try:
                raw = await asyncio.wait_for(
                    ws.recv(), timeout=min(2.0, deadline - time.time()))
            except asyncio.TimeoutError:
                continue
            except websockets.ConnectionClosed:
                break
            frame = parse_frame(raw)
            if frame.method == 1:
                evt = json.loads(frame.payload)
                et = evt.get("header", {}).get("event_type", "")
                print(f"  [WS] 收到事件: {et}")
                events.append(evt)


# ── 生成测试用的假 PNG 数据 ──


def _make_tiny_png():
    """最小合法 PNG: 1x1 红色像素"""
    import struct, zlib
    sig = b'\x89PNG\r\n\x1a\n'
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    ihdr = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
    raw = zlib.compress(b'\x00\xff\x00\x00')
    return sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', raw) + chunk(b'IEND', b'')


# ── 各测试步骤 ──


def _extract_text(content_json: dict) -> str:
    """从飞书消息 content 中提取文本，支持 text 和 post 类型。"""
    # text 类型: {"text": "hello"}
    if "text" in content_json:
        return content_json["text"]
    # post 类型: {"zh_cn": {"content": [[{"tag": "md", "text": "..."}]]}}
    for lang in content_json.values():
        if isinstance(lang, dict) and "content" in lang:
            parts = []
            for line in lang["content"]:
                for node in line:
                    if isinstance(node, dict) and "text" in node:
                        parts.append(node["text"])
            if parts:
                return "\n".join(parts)
    return ""


def test_1_bot_reply(client: CoflyClient, bot_id: str, timeout: int):
    """发消息给 bot，流式输出回复内容"""
    print("\n[测试 1/6] 发消息给 bot，等待回复...")

    import threading
    events = []
    ws_ready = threading.Event()
    stop_event_async = None
    loop = None

    def _run_ws():
        nonlocal stop_event_async, loop
        async def _inner():
            nonlocal stop_event_async, loop
            loop = asyncio.get_event_loop()
            stop_event_async = asyncio.Event()
            ws_ready.set()
            await ws_listen(client.base, client.token, events, timeout, stop_event_async)
        asyncio.run(_inner())

    t = threading.Thread(target=_run_ws, daemon=True)
    t.start()
    ws_ready.wait(timeout=5)
    time.sleep(0.5)  # 等 WS 握手完成

    test_text = f"hello from clawdbot test ({int(time.time())})"
    data = client.send_message(bot_id, test_text)
    msg_id = data["message_id"]
    print(f"  已发送: {msg_id}")
    print(f"  等待 bot 回复...")

    # 等待第一条消息事件到达（最多 timeout 秒）
    deadline = time.time() + timeout
    while time.time() < deadline and not events:
        time.sleep(0.5)

    if not events:
        print("  ✗ 超时：未收到回复")
        return None

    # 收到消息后，轮询 GET 接口流式输出内容，直到内容稳定
    msg_events = [e for e in events
                  if e.get("header", {}).get("event_type") == "im.message.receive_v1"]
    if not msg_events:
        print("  ✗ 未收到 im.message.receive_v1 事件")
        return None

    reply_msg_id = msg_events[0]["event"]["message"].get("message_id", "")
    prev_text = ""
    stable_count = 0
    idle_limit = 3  # 内容连续 N 次不变则认为完成
    poll_interval = 2.0

    print(f"  ── 回复内容 ({reply_msg_id}) ──")
    while time.time() < deadline:
        try:
            item = client.get_message(reply_msg_id)
            content = json.loads(item["body"]["content"])
            text = _extract_text(content)
        except Exception:
            text = ""

        if text != prev_text:
            # 打印新增部分
            new_part = text[len(prev_text):]
            if new_part:
                print(new_part, end="", flush=True)
            prev_text = text
            stable_count = 0
        else:
            stable_count += 1
            if prev_text and stable_count >= idle_limit:
                break

        time.sleep(poll_interval)

    print()  # 换行
    print(f"  ── 结束 ──")

    # 停止 WS 监听
    if stop_event_async and loop:
        loop.call_soon_threadsafe(stop_event_async.set)
    t.join(timeout=3)

    if prev_text:
        print(f"  ✓ 收到回复（{len(prev_text)} 字符）")
    else:
        print("  ✓ 收到回复（内容为空）")
    return msg_id


def test_2_patch_message(client: CoflyClient, bot_id: str):
    """发消息后编辑它，验证内容已更新"""
    print("\n[测试 2/6] 消息编辑 (PATCH)...")

    data = client.send_message(bot_id, "原始消息")
    msg_id = data["message_id"]
    print(f"  已发送: {msg_id}")

    client.patch_message(msg_id, "已编辑的消息")
    item = client.get_message(msg_id)
    actual = json.loads(item["body"]["content"])
    assert actual["text"] == "已编辑的消息", f"编辑后内容不匹配: {actual}"
    print("  ✓ PATCH 成功，内容已更新")


def test_3_image_upload_download(client: CoflyClient):
    """上传图片 → 下载图片 → 验证一致"""
    print("\n[测试 3/6] 图片上传/下载...")

    png_data = _make_tiny_png()
    image_key = client.upload_image(png_data)
    print(f"  上传成功: image_key={image_key}")

    downloaded = client.download_image(image_key)
    assert downloaded == png_data, "下载的图片与上传的不一致"
    print("  ✓ 下载验证通过")

    return image_key


def test_4_file_upload_and_resource(client: CoflyClient, bot_id: str):
    """上传文件 → 发送文件消息 → 通过 resource 接口下载"""
    print("\n[测试 4/6] 文件上传/下载 + 消息资源...")

    file_content = b"hello from cofly integration test\n"
    file_key = client.upload_file(file_content, "test.txt", "stream")
    print(f"  上传成功: file_key={file_key}")

    # 发送文件消息
    content = json.dumps({"file_key": file_key, "file_name": "test.txt"})
    data = client.send_message(bot_id, content, msg_type="file")
    msg_id = data["message_id"]
    print(f"  文件消息已发送: {msg_id}")

    # 通过 resource 接口下载
    downloaded = client.download_resource(msg_id, file_key)
    assert downloaded == file_content, "resource 下载内容不一致"
    print("  ✓ 资源下载验证通过")


def test_5_reactions(client: CoflyClient, bot_id: str):
    """添加 reaction → 列出 → 删除 → 验证已清空"""
    print("\n[测试 5/6] Reactions...")

    data = client.send_message(bot_id, "reaction test")
    msg_id = data["message_id"]

    # 添加
    r = client.add_reaction(msg_id, "THUMBSUP")
    rid = r["reaction_id"]
    print(f"  添加 reaction: {rid}")

    # 列出
    lr = client.list_reactions(msg_id)
    assert len(lr["items"]) == 1
    assert lr["items"][0]["reaction_type"]["emoji_type"] == "THUMBSUP"
    print("  ✓ 列出验证通过")

    # 删除
    client.delete_reaction(msg_id, rid)
    lr2 = client.list_reactions(msg_id)
    assert len(lr2["items"]) == 0
    print("  ✓ 删除验证通过")


def test_6_image_message(client: CoflyClient, bot_id: str, image_key: str):
    """发送图片消息，验证消息内容包含 image_key"""
    print("\n[测试 6/6] 图片消息...")

    content = json.dumps({"image_key": image_key})
    data = client.send_message(bot_id, content, msg_type="image")
    msg_id = data["message_id"]

    item = client.get_message(msg_id)
    assert item["msg_type"] == "image"
    body = json.loads(item["body"]["content"])
    assert body["image_key"] == image_key
    print(f"  ✓ 图片消息发送成功: {msg_id}")


# ── 主流程 ──


def run_all(base_url: str, timeout: int):
    client = CoflyClient(base_url)
    passed = 0
    failed = 0

    # 准备：查询 bot，tester 登录
    print("=== Cofly 全功能集成测试 ===\n")
    print("[准备] 查询 bot 并登录 tester...")

    bot_id = client.lookup_user(BOT_USERNAME)
    if not bot_id:
        # bot 未注册，说明 clawdbot 还没连过来，尝试用 token 接口触发自动创建
        print(f"  bot '{BOT_USERNAME}' 不存在，尝试通过 token 接口触发创建...")
        try:
            client.login(BOT_USERNAME, "placeholder")
        except AssertionError:
            pass
        bot_id = client.lookup_user(BOT_USERNAME)

    if not bot_id:
        print(f"  错误：bot '{BOT_USERNAME}' 仍不存在。请确认 clawdbot 已连接 cofly。")
        return False

    print(f"  bot_id = {bot_id}")

    client.login(TESTER_USERNAME, TESTER_PASSWORD)
    print(f"  tester 已登录")

    # 测试 1: bot 回复（需要 clawdbot 在线）
    try:
        msg_id = test_1_bot_reply(client, bot_id, timeout)
        if msg_id:
            passed += 1
        else:
            failed += 1
            print("  (bot 可能不在线，后续测试仍继续)")
    except Exception as e:
        failed += 1
        print(f"  ✗ 异常: {e}")

    # 测试 2: 消息编辑
    try:
        test_2_patch_message(client, bot_id)
        passed += 1
    except Exception as e:
        failed += 1
        print(f"  ✗ 异常: {e}")

    # 测试 3: 图片上传/下载
    image_key = None
    try:
        image_key = test_3_image_upload_download(client)
        passed += 1
    except Exception as e:
        failed += 1
        print(f"  ✗ 异常: {e}")

    # 测试 4: 文件上传 + 资源下载
    try:
        test_4_file_upload_and_resource(client, bot_id)
        passed += 1
    except Exception as e:
        failed += 1
        print(f"  ✗ 异常: {e}")

    # 测试 5: Reactions
    try:
        test_5_reactions(client, bot_id)
        passed += 1
    except Exception as e:
        failed += 1
        print(f"  ✗ 异常: {e}")

    # 测试 6: 图片消息
    if image_key:
        try:
            test_6_image_message(client, bot_id, image_key)
            passed += 1
        except Exception as e:
            failed += 1
            print(f"  ✗ 异常: {e}")
    else:
        print("\n[测试 6/6] 跳过（图片上传失败）")
        failed += 1

    # 汇总
    total = passed + failed
    print(f"\n{'='*40}")
    print(f"结果: {passed}/{total} 通过")
    if failed:
        print(f"      {failed}/{total} 失败")
    print(f"{'='*40}")
    return failed == 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cofly 全功能集成测试")
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument("--timeout", type=int, default=120,
                        help="等待 bot 回复的超时秒数")
    args = parser.parse_args()

    success = run_all(args.base_url, args.timeout)
    sys.exit(0 if success else 1)
