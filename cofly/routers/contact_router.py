from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from auth import get_current_user
from database import get_db
from models import User

router = APIRouter()


def _user_to_dict(u: User) -> dict:
    return {
        "open_id": u.id,
        "user_id": u.id,
        "union_id": u.id,
        "name": u.display_name,
        "en_name": u.username,
        "nickname": u.display_name,
        "email": u.email or "",
        "mobile": u.mobile or "",
        "department_ids": [u.department] if u.department else [],
    }


@router.get("/open-apis/contact/v3/users/{user_id}")
def get_user_info(
    user_id: str,
    user_id_type: str = Query("open_id"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # user_id_type 参数兼容飞书 SDK，cofly 中 open_id == user_id
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        return {"code": 1, "msg": "user not found", "data": {}}
    return {"code": 0, "msg": "ok", "data": {"user": _user_to_dict(target)}}


@router.get("/cofly/users/{username}")
def lookup_user_by_username(
    username: str,
    db: Session = Depends(get_db),
):
    """Cofly 专用：按 username 查询用户"""
    target = db.query(User).filter(User.username == username).first()
    if not target:
        return {"code": 1, "msg": "user not found", "data": {}}
    return {"code": 0, "msg": "ok", "data": {"user": _user_to_dict(target)}}


@router.get("/open-apis/bot/v3/info")
def get_bot_info(
    user: User = Depends(get_current_user),
):
    """SDK 调用此接口获取 bot 自身的 open_id"""
    return {"code": 0, "msg": "ok", "bot": {
        "bot_name": user.display_name,
        "open_id": user.id,
    }}
