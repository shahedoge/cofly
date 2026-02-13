import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, Text, DateTime, ForeignKey, LargeBinary, PrimaryKeyConstraint

from database import Base

# Namespace for deterministic user IDs
_COFLY_NS = uuid.UUID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")


def _uuid():
    return str(uuid.uuid4())


def _now():
    return datetime.now(timezone.utc)


def make_user_id(username: str) -> str:
    """Generate a deterministic user_id from username."""
    return str(uuid.uuid5(_COFLY_NS, username))


class User(Base):
    __tablename__ = "users"
    id = Column(Text, primary_key=True, default=_uuid)
    username = Column(Text, unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    display_name = Column(Text, default="")
    email = Column(Text, default="")
    mobile = Column(Text, default="")
    department = Column(Text, default="")
    created_at = Column(DateTime, default=_now)


class Chat(Base):
    __tablename__ = "chats"
    id = Column(Text, primary_key=True, default=_uuid)
    chat_type = Column(Text, default="p2p")
    name = Column(Text, default="")
    owner_id = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_now)


class ChatMember(Base):
    __tablename__ = "chat_members"
    chat_id = Column(Text, ForeignKey("chats.id"), nullable=False)
    user_id = Column(Text, ForeignKey("users.id"), nullable=False)
    joined_at = Column(DateTime, default=_now)
    __table_args__ = (PrimaryKeyConstraint("chat_id", "user_id"),)


class Message(Base):
    __tablename__ = "messages"
    id = Column(Text, primary_key=True, default=_uuid)
    chat_id = Column(Text, ForeignKey("chats.id"), nullable=False)
    sender_id = Column(Text, ForeignKey("users.id"), nullable=False)
    message_type = Column(Text, default="text")
    content = Column(Text, default="")
    root_id = Column(Text, default="")
    parent_id = Column(Text, default="")
    created_at = Column(DateTime, default=_now)


class Media(Base):
    __tablename__ = "media"
    id = Column(Text, primary_key=True, default=_uuid)
    uploader_id = Column(Text, ForeignKey("users.id"), nullable=False)
    file_name = Column(Text, default="")
    content_type = Column(Text, default="application/octet-stream")
    data = Column(LargeBinary, nullable=False)
    media_type = Column(Text, default="image")  # "image" or "file"
    created_at = Column(DateTime, default=_now)


class Reaction(Base):
    __tablename__ = "reactions"
    id = Column(Text, primary_key=True, default=_uuid)
    message_id = Column(Text, ForeignKey("messages.id"), nullable=False)
    user_id = Column(Text, ForeignKey("users.id"), nullable=False)
    emoji_type = Column(Text, nullable=False)
    created_at = Column(DateTime, default=_now)
