from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from auth import hash_password, verify_password, create_token, verify_registration_token
from database import get_db
from models import User, make_user_id
from schemas import RegisterRequest, TokenRequest

router = APIRouter()


@router.post("/cofly/register")
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    if not verify_registration_token(req.registration_token):
        return {"code": 1, "msg": "invalid registration token", "data": {}}
    if db.query(User).filter(User.username == req.username).first():
        return {"code": 1, "msg": "username already exists", "data": {}}
    user = User(
        id=req.open_id or make_user_id(req.username),
        username=req.username,
        password_hash=hash_password(req.password),
        display_name=req.display_name or req.username,
        email=req.email or "",
        mobile=req.mobile or "",
        department=req.department or "",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"code": 0, "msg": "ok", "data": {"user_id": user.id}}


@router.post("/open-apis/auth/v3/tenant_access_token/internal")
def get_token(req: TokenRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == req.app_id).first()
    if not user:
        if not verify_registration_token(None):
            return {"code": 1, "msg": "user not registered", "tenant_access_token": "", "expire": 0}
        # Auto-register: in real Feishu the app already exists,
        # cofly auto-creates on first token request for convenience.
        user = User(
            id=make_user_id(req.app_id),
            username=req.app_id,
            password_hash=hash_password(req.app_secret),
            display_name=req.app_id,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    elif not user.password_hash:
        # User was auto-created (via WS or token lookup) with empty hash; set password now.
        user.password_hash = hash_password(req.app_secret)
        db.commit()
    elif not verify_password(req.app_secret, user.password_hash):
        return {"code": 1, "msg": "invalid credentials", "tenant_access_token": "", "expire": 0}
    token = create_token(user.id, user.username)
    return {"code": 0, "msg": "ok", "tenant_access_token": token, "expire": 7200}
