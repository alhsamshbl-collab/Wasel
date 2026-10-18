from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.dependencies import current_user
from app.models import User, Conversation, ConversationMember

router = APIRouter()

@router.get('/global-group')
async def get_global_group(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    group = await db.scalar(select(Conversation).where(Conversation.kind == 'global').order_by(Conversation.id).limit(1))
    if group is None:
        group = Conversation(kind='global', title='المجموعة العامة')
        db.add(group)
        await db.flush()
    active_users = list((await db.scalars(select(User).where(User.is_active.is_(True)))).all())
    existing = set((await db.scalars(select(ConversationMember.user_id).where(ConversationMember.conversation_id == group.id))).all())
    for member in active_users:
        if member.id not in existing:
            db.add(ConversationMember(conversation_id=group.id, user_id=member.id))
    await db.commit()
    return {'id': group.id, 'kind': 'global', 'title': 'المجموعة العامة', 'member_count': len(active_users)}
