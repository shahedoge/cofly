from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, Query, Request
from sqlalchemy.orm import Session

from auth import decode_token
from database import get_db, SessionLocal
from models import User, make_user_id
from ws_manager import ws_manager
from proto import parse_frame, get_header

router = APIRouter()


@router.get("/cofly/online/{user_id}")
def check_online(user_id: str):
    """Check if a user is connected via WebSocket."""
    return {"online": ws_manager.is_online(user_id)}


@router.post("/callback/ws/endpoint")
async def ws_endpoint(request: Request, db: Session = Depends(get_db)):
    """Return WS URL and client config, mimicking Feishu's endpoint discovery.
    SDK sends {"AppID": "...", "AppSecret": "..."} in the body."""
    import logging
    from auth import create_token, hash_password, verify_password, verify_registration_token
    logger = logging.getLogger("cofly.ws")

    host = request.headers.get("host", "localhost:8000")
    # Behind a reverse proxy, request.url.scheme is "http" even when the
    # client connected via HTTPS.  Check X-Forwarded-Proto / X-Forwarded-Ssl
    # headers that proxies (nginx, caddy, etc.) typically set.
    forwarded_proto = (
        request.headers.get("x-forwarded-proto")
        or request.headers.get("x-forwarded-ssl")
        or ""
    ).lower()
    if forwarded_proto in ("https", "on"):
        scheme = "wss"
    elif request.url.scheme == "https":
        scheme = "wss"
    else:
        scheme = "ws"

    token = ""

    # Try Authorization header first (test clients)
    auth = request.headers.get("authorization", "")
    if auth.startswith("Bearer "):
        token = auth.removeprefix("Bearer ").strip()

    # Try body credentials (Lark SDK sends AppID/AppSecret here)
    if not token:
        try:
            body = await request.json()
        except Exception:
            body = {}
        app_id = body.get("AppID") or body.get("app_id") or ""
        app_secret = body.get("AppSecret") or body.get("app_secret") or ""
        if app_id:
            user = db.query(User).filter(User.username == app_id).first()
            if not user:
                if not verify_registration_token(None):
                    return {"code": 1, "msg": "user not registered", "data": {}}
                user = User(
                    id=make_user_id(app_id),
                    username=app_id,
                    password_hash=hash_password(app_secret) if app_secret else "",
                    display_name=app_id,
                )
                db.add(user)
                db.commit()
                db.refresh(user)
            elif not user.password_hash and app_secret:
                user.password_hash = hash_password(app_secret)
                db.commit()
            token = create_token(user.id, user.username)

    logger.info("ws_endpoint called: host=%s, has_token=%s", host, bool(token))

    ws_url = f"{scheme}://{host}/ws"
    if token:
        ws_url += f"?token={token}"

    return {
        "code": 0,
        "msg": "ok",
        "data": {
            "URL": ws_url,
            "ClientConfig": {
                "ReconnectCount": 10,
                "ReconnectInterval": 3,
                "ReconnectNonce": 5,
                "PingInterval": 120,
            },
        },
    }


@router.websocket("/ws")
async def websocket_handler(ws: WebSocket):
    import logging
    logger = logging.getLogger("cofly.ws")

    # Extract token from query params
    token = ws.query_params.get("token", "")
    logger.info("WS connect attempt: path=%s, has_token=%s, query=%s",
                ws.url.path, bool(token), dict(ws.query_params))

    if not token:
        logger.warning("WS rejected: no token")
        await ws.close(code=4001, reason="missing token")
        return

    try:
        data = decode_token(token)
    except Exception as e:
        logger.warning("WS rejected: invalid token: %s", e)
        await ws.close(code=4001, reason="invalid token")
        return

    user_id = data["sub"]

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user and "username" in data:
            username = data["username"]
            user = db.query(User).filter(User.username == username).first()
            if not user:
                from auth import verify_registration_token
                if not verify_registration_token(None):
                    await ws.close(code=4001, reason="user not registered")
                    return
                user = User(
                    id=make_user_id(username),
                    username=username,
                    password_hash="",
                    display_name=username,
                )
                db.add(user)
                db.commit()
                db.refresh(user)
            user_id = user.id
    finally:
        db.close()

    if not user:
        await ws.close(code=4001, reason="user not found")
        return

    await ws_manager.connect(user_id, ws)
    try:
        while True:
            raw = await ws.receive_bytes()
            await ws_manager.handle_frame(user_id, raw)
    except WebSocketDisconnect:
        pass
    finally:
        ws_manager.disconnect(user_id)
