from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.dependencies import current_user
from app.models import User, UserBlock, Conversation, ConversationMember

router = APIRouter()

class ConversationCreate(BaseModel):
    user_ids: list[int] = Field(min_length=1, max_length=5)
    title: str | None = Field(default=None, max_length=120)

@router.post("/conversations", status_code=201)
async def create_conversation(data: ConversationCreate, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    member_ids = list(dict.fromkeys([user.id, *data.user_ids]))
    if len(member_ids) > 6:
        raise HTTPException(400, "يسمح بستة أعضاء كحد أقصى")
    targets = list((await db.scalars(select(User).where(User.id.in_(member_ids), User.is_active.is_(True)))).all())
    if len(targets) != len(member_ids):
        raise HTTPException(404, "أحد المستخدمين غير موجود")
    if len(member_ids) == 2:
        blocked = await db.scalar(select(UserBlock.id).where(or_(
            and_(UserBlock.blocker_id == member_ids[0], UserBlock.blocked_id == member_ids[1]),
            and_(UserBlock.blocker_id == member_ids[1], UserBlock.blocked_id == member_ids[0]))))
        if blocked:
            raise HTTPException(403, "لا يمكن بدء محادثة بسبب الحظر")
    conversation = Conversation(kind="private" if len(member_ids) == 2 else "group", title=data.title)
    db.add(conversation)
    await db.flush()
    db.add_all([ConversationMember(conversation_id=conversation.id, user_id=member_id) for member_id in member_ids])
    await db.commit()
    await db.refresh(conversation)
    return {"id": conversation.id, "kind": conversation.kind, "title": conversation.title, "member_ids": member_ids}
