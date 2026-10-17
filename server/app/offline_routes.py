from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.dependencies import current_user
from app.models import User, ConversationMember, Message, MessageReceipt, MessageAttachment

router = APIRouter()

@router.post("/conversations/{conversation_id}/messages/{message_id}/ack", status_code=200)
async def acknowledge_saved_message(conversation_id: int, message_id: int,
    user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    member = await db.scalar(select(ConversationMember.id).where(
        ConversationMember.conversation_id == conversation_id,
        ConversationMember.user_id == user.id))
    if not member:
        raise HTTPException(403, "لست عضوًا في هذه المحادثة")
    message = await db.scalar(select(Message).where(
        Message.id == message_id, Message.conversation_id == conversation_id))
    if message is None:
        raise HTTPException(404, "الرسالة غير موجودة")
    if message.cloud_purged:
        return {"saved": True, "cloud_purged": True}
    receipt = await db.scalar(select(MessageReceipt).where(
        MessageReceipt.message_id == message_id, MessageReceipt.user_id == user.id))
    if receipt is None:
        db.add(MessageReceipt(message_id=message_id, user_id=user.id))
        await db.flush()
    member_count = await db.scalar(select(func.count()).select_from(ConversationMember).where(
        ConversationMember.conversation_id == conversation_id))
    receipt_count = await db.scalar(select(func.count()).select_from(MessageReceipt).where(
        MessageReceipt.message_id == message_id))
    attachments = list((await db.scalars(select(MessageAttachment).where(
        MessageAttachment.message_id == message_id))).all())
    purged = False
    waiting_for_media = bool(attachments)
    if member_count and receipt_count >= member_count and not waiting_for_media:
        # Keep a tombstone for sync integrity; never purge text before media is safely cached.
        message.content = None
        message.cloud_purged = True
        purged = True
    await db.commit()
    return {"saved": True, "cloud_purged": purged, "waiting_for_media": waiting_for_media,
            "acknowledged_users": receipt_count, "conversation_members": member_count or 0}
