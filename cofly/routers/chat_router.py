from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from auth import get_current_user
from database import get_db
from models import User, Chat, ChatMember

router = APIRouter()


@router.get("/open-apis/im/v1/chats")
def list_chats(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memberships = db.query(ChatMember).filter(ChatMember.user_id == user.id).all()
    items = []
    for m in memberships:
        chat = db.query(Chat).filter(Chat.id == m.chat_id).first()
        if chat:
            items.append({
                "chat_id": chat.id,
                "chat_type": chat.chat_type,
                "name": chat.name,
                "owner_id": chat.owner_id or "",
            })
    return {"code": 0, "msg": "ok", "data": {
        "items": items,
        "has_more": False,
        "page_token": "",
    }}
