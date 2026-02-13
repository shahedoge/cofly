#!/usr/bin/env python3
"""
预注册 bot 用户到 cofly。

在 cofly 启动后、openclaw 启动前运行：
    python seed_bot.py [--base-url http://localhost:8000]
"""

import argparse
import os
import requests
import sys

DEFAULT_BOTS = [
    {
        "username": "<bot app id>",
        "password": "<bot app secret key>",
        "display_name": "<bot display name>",
    },
]


def seed(base_url: str, bots: list[dict], token: str = ""):
    base = base_url.rstrip("/")
    for bot in bots:
        # 注册
        payload = {**bot}
        if token:
            payload["registration_token"] = token
        r = requests.post(f"{base}/cofly/register", json=payload)
        body = r.json()
        if body["code"] == 0:
            print(f"  注册成功: {bot['username']} -> {body['data']['user_id']}")
        elif "already exists" in body.get("msg", ""):
            print(f"  已存在: {bot['username']}")
        else:
            print(f"  注册失败: {body}")
            continue

        # 预获取 token，确保后续 bot info 接口可用
        r = requests.post(
            f"{base}/open-apis/auth/v3/tenant_access_token/internal",
            json={"app_id": bot["username"], "app_secret": bot["password"]},
        )
        body = r.json()
        if body["code"] == 0:
            print(f"  token OK: {body['tenant_access_token'][:20]}...")
        else:
            print(f"  token 失败: {body}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="预注册 bot 到 cofly")
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument("--token", default=os.getenv("COFLY_REGISTRATION_TOKEN", ""))
    args = parser.parse_args()

    try:
        requests.get(args.base_url)
    except requests.ConnectionError:
        print(f"错误：无法连接 {args.base_url}，请确认 cofly 已启动")
        sys.exit(1)

    seed(args.base_url, DEFAULT_BOTS, args.token)
    print("\ndone. 现在可以启动 openclaw 了。")
