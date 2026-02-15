import calendar
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from auth import get_current_user
from database import get_db
from models import User, Chat, ChatMember, Message
from schemas import SendMessageRequest, ReplyMessageRequest, PatchMessageRequest
from ws_manager import ws_manager, build_message_event, build_message_sync_event, build_message_update_event, build_ack_event

router = APIRouter()


def _find_or_create_p2p_chat(db: Session, user_a_id: str, user_b_id: str) -> Chat:
    """Find existing p2p chat between two users, or create one."""
    existing = (
        db.query(Chat)
        .join(ChatMember, Chat.id == ChatMember.chat_id)
        .filter(Chat.chat_type == "p2p")
        .filter(ChatMember.user_id == user_a_id)
        .all()
    )
    for chat in existing:
        other = (
            db.query(ChatMember)
            .filter(ChatMember.chat_id == chat.id, ChatMember.user_id == user_b_id)
            .first()
        )
        if other:
            return chat

    chat = Chat(chat_type="p2p", owner_id=user_a_id)
    db.add(chat)
    db.flush()
    db.add(ChatMember(chat_id=chat.id, user_id=user_a_id))
    db.add(ChatMember(chat_id=chat.id, user_id=user_b_id))
    db.commit()
    db.refresh(chat)
    return chat


async def _save_and_push(
    db: Session, sender: User, chat: Chat, msg_type: str, content: str,
    root_id: str = "", parent_id: str = "",
) -> Message:
    msg = Message(
        chat_id=chat.id,
        sender_id=sender.id,
        message_type=msg_type,
        content=content,
        root_id=root_id,
        parent_id=parent_id,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    # Push to all members; sender gets sync event (ignored by Lark SDK bots),
    # others get receive event.
    any_bot_delivered = False
    members = db.query(ChatMember).filter(ChatMember.chat_id == chat.id).all()
    for m in members:
        target_user = db.query(User).filter(User.id == m.user_id).first()
        if not target_user:
            continue
        build = build_message_sync_event if m.user_id == sender.id else build_message_event
        event = build(
            sender_id=sender.id,
            receiver_username=target_user.username,
            message_id=msg.id,
            chat_id=chat.id,
            chat_type=chat.chat_type,
            message_type=msg.message_type,
            content=msg.content,
            root_id=msg.root_id,
            parent_id=msg.parent_id,
        )
        delivered = await ws_manager.push_event(m.user_id, event)
        if delivered and m.user_id != sender.id:
            any_bot_delivered = True

    # Push ack back to sender
    ack = build_ack_event(
        message_id=msg.id,
        chat_id=chat.id,
        receiver_username=sender.username,
        bot_delivered=any_bot_delivered,
    )
    await ws_manager.push_event(sender.id, ack)

    return msg


@router.post("/open-apis/im/v1/messages")
async def send_message(
    req: SendMessageRequest,
    receive_id_type: str = Query("open_id"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if receive_id_type in ("open_id", "user_id"):
        target = db.query(User).filter(User.id == req.receive_id).first()
        if not target:
            return {"code": 1, "msg": "receiver not found", "data": {}}
        chat = _find_or_create_p2p_chat(db, user.id, target.id)
    elif receive_id_type == "chat_id":
        chat = db.query(Chat).filter(Chat.id == req.receive_id).first()
        if not chat:
            return {"code": 1, "msg": "chat not found", "data": {}}
    else:
        return {"code": 1, "msg": "unsupported receive_id_type", "data": {}}

    msg = await _save_and_push(db, user, chat, req.msg_type, req.content)
    return {"code": 0, "msg": "ok", "data": {
        "message_id": msg.id,
        "chat_id": msg.chat_id,
        "create_time": str(int(calendar.timegm(msg.created_at.timetuple()) * 1000)),
    }}


@router.post("/open-apis/im/v1/messages/{message_id}/reply")
async def reply_message(
    message_id: str,
    req: ReplyMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    parent = db.query(Message).filter(Message.id == message_id).first()
    if not parent:
        return {"code": 1, "msg": "parent message not found", "data": {}}
    chat = db.query(Chat).filter(Chat.id == parent.chat_id).first()
    root_id = parent.root_id if parent.root_id else parent.id
    msg = await _save_and_push(
        db, user, chat, req.msg_type, req.content,
        root_id=root_id, parent_id=parent.id,
    )
    return {"code": 0, "msg": "ok", "data": {
        "message_id": msg.id,
        "chat_id": msg.chat_id,
        "create_time": str(int(calendar.timegm(msg.created_at.timetuple()) * 1000)),
    }}


@router.get("/open-apis/im/v1/messages/{message_id}")
def get_message(
    message_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg:
        return {"code": 1, "msg": "message not found", "data": {}}
    sender = db.query(User).filter(User.id == msg.sender_id).first()
    return {"code": 0, "msg": "ok", "data": {
        "items": [{
            "message_id": msg.id,
            "chat_id": msg.chat_id,
            "msg_type": msg.message_type,
            "body": {"content": msg.content},
            "sender": {
                "id": msg.sender_id,
                "id_type": "open_id",
                "sender_type": "user",
                "tenant_key": "cofly",
            },
            "root_id": msg.root_id,
            "parent_id": msg.parent_id,
            "create_time": str(int(calendar.timegm(msg.created_at.timetuple()) * 1000)),
        }]
    }}


@router.patch("/open-apis/im/v1/messages/{message_id}")
async def patch_message(
    message_id: str,
    req: PatchMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg:
        return {"code": 1, "msg": "message not found", "data": {}}
    if msg.sender_id != user.id:
        return {"code": 1, "msg": "no permission to edit this message", "data": {}}
    msg.message_type = req.msg_type
    msg.content = req.content
    db.commit()
    db.refresh(msg)

    # Push update event to chat members
    chat = db.query(Chat).filter(Chat.id == msg.chat_id).first()
    if chat:
        members = db.query(ChatMember).filter(ChatMember.chat_id == chat.id).all()
        for m in members:
            target_user = db.query(User).filter(User.id == m.user_id).first()
            if not target_user:
                continue
            event = build_message_update_event(
                sender_id=user.id,
                receiver_username=target_user.username,
                message_id=msg.id,
                chat_id=chat.id,
                chat_type=chat.chat_type,
                message_type=msg.message_type,
                content=msg.content,
            )
            await ws_manager.push_event(m.user_id, event)

    return {"code": 0, "msg": "ok", "data": {
        "message_id": msg.id,
        "chat_id": msg.chat_id,
        "msg_type": msg.message_type,
        "body": {"content": msg.content},
        "update_time": str(int(calendar.timegm(msg.created_at.timetuple()) * 1000)),
    }}


@router.get("/open-apis/im/v1/chats/{chat_id}/messages")
def list_chat_messages(
    chat_id: str,
    page_size: int = Query(100, ge=1, le=500),
    start_time: Optional[int] = Query(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List messages in a chat, optionally filtered by start_time (ms timestamp)."""
    chat = db.query(Chat).filter(Chat.id == chat_id).first()
    if not chat:
        return {"code": 1, "msg": "chat not found", "data": {}}

    # Verify user is a member of this chat
    member = (
        db.query(ChatMember)
        .filter(ChatMember.chat_id == chat_id, ChatMember.user_id == user.id)
        .first()
    )
    if not member:
        return {"code": 1, "msg": "not a member of this chat", "data": {}}

    query = db.query(Message).filter(Message.chat_id == chat_id)

    if start_time is not None:
        cutoff = datetime.utcfromtimestamp(start_time / 1000)
        query = query.filter(Message.created_at >= cutoff)

    messages = (
        query.order_by(Message.created_at.asc())
        .limit(page_size)
        .all()
    )

    items = []
    for msg in messages:
        items.append({
            "message_id": msg.id,
            "chat_id": msg.chat_id,
            "msg_type": msg.message_type,
            "body": {"content": msg.content},
            "sender": {
                "id": msg.sender_id,
                "id_type": "open_id",
                "sender_type": "user",
                "tenant_key": "cofly",
            },
            "root_id": msg.root_id,
            "parent_id": msg.parent_id,
            "create_time": str(int(calendar.timegm(msg.created_at.timetuple()) * 1000)),
        })

    return {"code": 0, "msg": "ok", "data": {"items": items}}
