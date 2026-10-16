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
    purged = False
    if member_count and receipt_count >= member_count:
        # Keep a tombstone row for sync integrity, but remove the message text from the cloud.
        message.content = None
        message.cloud_purged = True
        attachments = list((await db.scalars(select(MessageAttachment).where(
            MessageAttachment.message_id == message_id))).all())
        # Actual object-store deletion is required before enabling media uploads.
        for attachment in attachments:
            await db.delete(attachment)
        purged = True
    await db.commit()
    return {"saved": True, "cloud_purged": purged, "acknowledged_users": receipt_count,
            "conversation_members": member_count or 0}
