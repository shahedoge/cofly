from pydantic import BaseModel
from typing import Optional


class RegisterRequest(BaseModel):
    username: str
    password: str
    display_name: str = ""
    open_id: Optional[str] = None
    email: Optional[str] = None
    mobile: Optional[str] = None
    department: Optional[str] = None
    registration_token: Optional[str] = None


class TokenRequest(BaseModel):
    app_id: str
    app_secret: str


class SendMessageRequest(BaseModel):
    receive_id: str
    msg_type: str = "text"
    content: str
    uuid: Optional[str] = None


class ReplyMessageRequest(BaseModel):
    msg_type: str = "text"
    content: str
    uuid: Optional[str] = None


class PatchMessageRequest(BaseModel):
    msg_type: str = "text"
    content: str


class AddReactionRequest(BaseModel):
    reaction_type: dict  # {"emoji_type": "THUMBSUP"}
