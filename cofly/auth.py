import time
from typing import Optional

import bcrypt
import jwt
from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from config import SECRET_KEY, TOKEN_EXPIRE_SECONDS, REGISTRATION_TOKEN
from database import get_db
from models import User, make_user_id


def verify_registration_token(token: str | None) -> bool:
    if not REGISTRATION_TOKEN:
        return True
    return token == REGISTRATION_TOKEN


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_token(user_id: str, username: str) -> str:
    payload = {
        "sub": user_id,
        "username": username,
        "exp": int(time.time()) + TOKEN_EXPIRE_SECONDS,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[7:]
    else:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    data = decode_token(token)
    user = db.query(User).filter(User.id == data["sub"]).first()
    if not user and "username" in data:
        # Token has a user_id not in DB (e.g. DB was rebuilt, or SDK cached old token).
        # Look up by username, or auto-create.
        username = data["username"]
        user = db.query(User).filter(User.username == username).first()
        if not user:
            if not verify_registration_token(None):
                raise HTTPException(status_code=401, detail="User not found and registration is restricted")
            user = User(
                id=make_user_id(username),
                username=username,
                password_hash="",
                display_name=username,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
