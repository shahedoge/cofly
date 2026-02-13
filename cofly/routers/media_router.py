from fastapi import APIRouter, Depends, UploadFile, File, Form
from fastapi.responses import Response
from sqlalchemy.orm import Session

from auth import get_current_user
from database import get_db
from models import User, Message, Media

router = APIRouter()


@router.post("/open-apis/im/v1/images")
async def upload_image(
    image_type: str = Form(...),
    image: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    data = await image.read()
    media = Media(
        uploader_id=user.id,
        file_name=image.filename or "image",
        content_type=image.content_type or "image/png",
        data=data,
        media_type="image",
    )
    db.add(media)
    db.commit()
    db.refresh(media)
    return {"code": 0, "msg": "ok", "data": {"image_key": media.id}}


@router.get("/open-apis/im/v1/images/{image_key}")
def download_image(
    image_key: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    media = db.query(Media).filter(Media.id == image_key, Media.media_type == "image").first()
    if not media:
        return {"code": 1, "msg": "image not found", "data": {}}
    return Response(content=media.data, media_type=media.content_type)


@router.post("/open-apis/im/v1/files")
async def upload_file(
    file_type: str = Form(...),
    file_name: str = Form(...),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    data = await file.read()
    media = Media(
        uploader_id=user.id,
        file_name=file_name,
        content_type=file.content_type or "application/octet-stream",
        data=data,
        media_type="file",
    )
    db.add(media)
    db.commit()
    db.refresh(media)
    return {"code": 0, "msg": "ok", "data": {"file_key": media.id}}


@router.get("/open-apis/im/v1/messages/{message_id}/resources/{file_key}")
def download_resource(
    message_id: str,
    file_key: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg:
        return {"code": 1, "msg": "message not found", "data": {}}
    media = db.query(Media).filter(Media.id == file_key).first()
    if not media:
        return {"code": 1, "msg": "resource not found", "data": {}}
    return Response(content=media.data, media_type=media.content_type)
