from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from auth import get_current_user
from database import get_db
from models import User, Message, Reaction
from schemas import AddReactionRequest

router = APIRouter()


@router.post("/open-apis/im/v1/messages/{message_id}/reactions")
def add_reaction(
    message_id: str,
    req: AddReactionRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg:
        return {"code": 1, "msg": "message not found", "data": {}}
    emoji_type = req.reaction_type.get("emoji_type", "")
    reaction = Reaction(
        message_id=message_id,
        user_id=user.id,
        emoji_type=emoji_type,
    )
    db.add(reaction)
    db.commit()
    db.refresh(reaction)
    return {"code": 0, "msg": "ok", "data": {
        "reaction_id": reaction.id,
        "reaction_type": {"emoji_type": reaction.emoji_type},
        "operator_type": "user",
        "user_id": user.id,
    }}


@router.delete("/open-apis/im/v1/messages/{message_id}/reactions/{reaction_id}")
def delete_reaction(
    message_id: str,
    reaction_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reaction = db.query(Reaction).filter(
        Reaction.id == reaction_id,
        Reaction.message_id == message_id,
    ).first()
    if not reaction:
        return {"code": 1, "msg": "reaction not found", "data": {}}
    db.delete(reaction)
    db.commit()
    return {"code": 0, "msg": "ok", "data": {}}


@router.get("/open-apis/im/v1/messages/{message_id}/reactions")
def list_reactions(
    message_id: str,
    page_token: str = Query(""),
    page_size: int = Query(50),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg:
        return {"code": 1, "msg": "message not found", "data": {}}
    reactions = db.query(Reaction).filter(
        Reaction.message_id == message_id,
    ).limit(page_size).all()
    items = [{
        "reaction_id": r.id,
        "reaction_type": {"emoji_type": r.emoji_type},
        "operator_type": "user",
        "user_id": r.user_id,
    } for r in reactions]
    return {"code": 0, "msg": "ok", "data": {
        "items": items,
        "has_more": False,
        "page_token": "",
    }}
