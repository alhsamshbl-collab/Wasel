from pathlib import Path
from uuid import uuid4
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.database.session import get_db
from app.dependencies import current_user
from app.models import User, ConversationMember, Message, MessageAttachment, Conversation, UserBlock

router = APIRouter()
ALLOWED_PREFIXES = ("image/", "video/", "audio/")

@router.post("/conversations/{conversation_id}/messages/{message_id}/attachments", status_code=201)
async def upload_attachment(conversation_id: int, message_id: int, file: UploadFile = File(...),
    user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    member = await db.scalar(select(ConversationMember.id).where(
        ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user.id))
    if not member:
        raise HTTPException(403, "لست عضوًا في هذه المحادثة")
    message = await db.scalar(select(Message).where(
        Message.id == message_id, Message.conversation_id == conversation_id, Message.sender_id == user.id))
    if message is None:
        raise HTTPException(404, "الرسالة غير موجودة أو لا تملك صلاحية إرفاق ملف بها")
    mime = (file.content_type or "application/octet-stream").lower()
    if not mime.startswith(ALLOWED_PREFIXES):
        raise HTTPException(415, "نوع الملف غير مدعوم؛ المسموح صور وفيديو وصوت")
    payload = await file.read(settings.max_upload_bytes + 1)
    if not payload or len(payload) > settings.max_upload_bytes:
        raise HTTPException(413, "الملف فارغ أو أكبر من الحد المسموح")
    root = Path(settings.upload_dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    key = f"{uuid4().hex}_{Path(file.filename or 'attachment.bin').name[:100]}"
    target = (root / key).resolve()
    if target.parent != root:
        raise HTTPException(400, "اسم ملف غير صالح")
    target.write_bytes(payload)
    attachment = MessageAttachment(message_id=message.id, object_key=key, content_type=mime,
        size_bytes=len(payload), original_name=Path(file.filename or "attachment").name[:255])
    db.add(attachment)
    await db.commit()
    await db.refresh(attachment)
    return {"id": attachment.id, "message_id": message.id, "name": attachment.original_name,
        "content_type": attachment.content_type, "size_bytes": attachment.size_bytes,
        "download_path": f"/api/attachments/{attachment.id}"}


@router.post("/conversations/{conversation_id}/media", status_code=201)
async def send_media(conversation_id: int, file: UploadFile = File(...),
    user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    """Create a media message and store its attachment for any member of this conversation."""
    member = await db.scalar(select(ConversationMember.id).where(
        ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user.id))
    if not member:
        raise HTTPException(403, "لست عضوًا في هذه المحادثة")
    conversation = await db.get(Conversation, conversation_id)
    if conversation is not None and conversation.kind == "private":
        peer_ids = list((await db.scalars(select(ConversationMember.user_id).where(
            ConversationMember.conversation_id == conversation_id, ConversationMember.user_id != user.id))).all())
        if peer_ids:
            blocked = await db.scalar(select(UserBlock.id).where(
                ((UserBlock.blocker_id == user.id) & (UserBlock.blocked_id.in_(peer_ids))) |
                ((UserBlock.blocker_id.in_(peer_ids)) & (UserBlock.blocked_id == user.id))))
            if blocked:
                raise HTTPException(403, "تعذر إرسال المرفق بسبب الحظر")
    mime = (file.content_type or "application/octet-stream").lower()
    payload = await file.read(settings.max_upload_bytes + 1)
    if not payload or len(payload) > settings.max_upload_bytes:
        raise HTTPException(413, "الملف فارغ أو أكبر من الحد المسموح")
    if mime.startswith("image/"):
        kind = "image"
    elif mime.startswith("video/"):
        kind = "video"
    elif mime.startswith("audio/"):
        kind = "audio"
    else:
        kind = "file"
    original_name = Path(file.filename or "attachment.bin").name[:255]
    root = Path(settings.upload_dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    key = f"{uuid4().hex}_{Path(original_name).name[:100]}"
    target = (root / key).resolve()
    if target.parent != root:
        raise HTTPException(400, "اسم ملف غير صالح")
    target.write_bytes(payload)
    message = Message(conversation_id=conversation_id, sender_id=user.id, kind=kind, content=None)
    db.add(message)
    await db.flush()
    attachment = MessageAttachment(message_id=message.id, object_key=key, content_type=mime,
        size_bytes=len(payload), original_name=original_name)
    db.add(attachment)
    await db.flush()
    message.content = __import__("json").dumps({
        "attachment_id": attachment.id, "name": original_name, "content_type": mime,
        "size_bytes": len(payload), "download_path": f"/api/attachments/{attachment.id}"
    }, ensure_ascii=False)
    await db.commit()
    await db.refresh(message)
    payload_out = {"type": "message", "id": message.id, "conversation_id": conversation_id,
        "sender_id": user.id, "kind": kind, "content": message.content,
        "created_at": message.created_at.isoformat()}
    from app.realtime import broadcast
    await broadcast(conversation_id, payload_out)
    return payload_out

@router.get("/attachments/{attachment_id}")
async def download_attachment(attachment_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    attachment = await db.get(MessageAttachment, attachment_id)
    if attachment is None:
        raise HTTPException(404, "المرفق غير موجود")
    message = await db.get(Message, attachment.message_id)
    if message is None:
        raise HTTPException(404, "المرفق غير موجود")
    member = await db.scalar(select(ConversationMember.id).where(
        ConversationMember.conversation_id == message.conversation_id, ConversationMember.user_id == user.id))
    if not member:
        raise HTTPException(403, "لا تملك صلاحية الوصول إلى هذا المرفق")
    root = Path(settings.upload_dir).resolve()
    target = (root / attachment.object_key).resolve()
    if target.parent != root or not target.is_file():
        raise HTTPException(404, "الملف غير موجود على الخادم")
    return FileResponse(target, media_type=attachment.content_type, filename=attachment.original_name)
