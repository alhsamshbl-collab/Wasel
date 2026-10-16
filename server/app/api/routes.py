from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, or_, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.database.session import get_db
from app.dependencies import current_user
from app.models import User, Conversation, ConversationMember, Message, UserBlock
from app.schemas import RegisterIn, LoginIn, TokenOut, UserOut, ProfilePatch
from app.security import hash_password, verify_password, create_access_token
router = APIRouter()
@router.post("/auth/register", response_model=TokenOut, status_code=201)
async def register(data: RegisterIn, db: AsyncSession = Depends(get_db)):
    if data.invite_code != settings.registration_code:
        raise HTTPException(403, "رمز الدعوة غير صحيح")
    count = await db.scalar(select(func.count()).select_from(User))
    if (count or 0) >= settings.max_users:
        raise HTTPException(403, "اكتمل عدد الحسابات المسموح به لهذا التطبيق")
    if await db.scalar(select(User.id).where(User.username == data.username)):
        raise HTTPException(409, "اسم المستخدم مستخدم بالفعل")
    user = User(username=data.username, display_name=data.display_name, password_hash=hash_password(data.password))
    db.add(user); await db.commit(); await db.refresh(user)
    return TokenOut(access_token=create_access_token(user.id), user=user)
@router.post("/auth/login", response_model=TokenOut)
async def login(data: LoginIn, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(User.username == data.username.strip().lower(), User.is_active.is_(True)))
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(401, "اسم المستخدم أو كلمة المرور غير صحيحة")
    return TokenOut(access_token=create_access_token(user.id), user=user)
@router.post("/auth/logout")
async def logout(user: User = Depends(current_user)):
    return {"success": True, "message": "احذف رمز الوصول من الجهاز"}
@router.get("/users/me", response_model=UserOut)
async def me(user: User = Depends(current_user)): return user
@router.get("/users", response_model=list[UserOut])
async def list_users(q: str = Query(default="", max_length=80), limit: int = Query(default=30, ge=1, le=100), offset: int = Query(default=0, ge=0), user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    blocked = select(UserBlock.blocked_id).where(UserBlock.blocker_id == user.id)
    blocked_by = select(UserBlock.blocker_id).where(UserBlock.blocked_id == user.id)
    stmt = select(User).where(User.id != user.id, User.is_active.is_(True), ~User.id.in_(blocked), ~User.id.in_(blocked_by))
    if q.strip(): stmt = stmt.where(or_(User.username.ilike(f"%{q.strip()}%"), User.display_name.ilike(f"%{q.strip()}%")))
    return list((await db.scalars(stmt.order_by(User.username).offset(offset).limit(limit))).all())
@router.get("/users/{user_id}", response_model=UserOut)
async def get_user(user_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    if user_id == user.id: return user
    blocked = await db.scalar(select(UserBlock.id).where(or_(and_(UserBlock.blocker_id == user.id, UserBlock.blocked_id == user_id), and_(UserBlock.blocker_id == user_id, UserBlock.blocked_id == user.id))))
    target = await db.get(User, user_id)
    if blocked or target is None or not target.is_active: raise HTTPException(404, "المستخدم غير موجود")
    return target
@router.patch("/users/me", response_model=UserOut)
async def patch_me(data: ProfilePatch, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    for key, value in data.model_dump(exclude_unset=True).items(): setattr(user, key, value)
    await db.commit(); await db.refresh(user); return user
@router.post("/users/{user_id}/block")
async def block_user(user_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    if user_id == user.id: raise HTTPException(400, "لا يمكنك حظر حسابك")
    if not await db.get(User, user_id): raise HTTPException(404, "المستخدم غير موجود")
    exists = await db.scalar(select(UserBlock.id).where(UserBlock.blocker_id == user.id, UserBlock.blocked_id == user_id))
    if not exists: db.add(UserBlock(blocker_id=user.id, blocked_id=user_id)); await db.commit()
    return {"success": True}
@router.delete("/users/{user_id}/block")
async def unblock_user(user_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    row = await db.scalar(select(UserBlock).where(UserBlock.blocker_id == user.id, UserBlock.blocked_id == user_id))
    if row: await db.delete(row); await db.commit()
    return {"success": True}
@router.get("/users/blocked", response_model=list[UserOut])
async def blocked_users(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(User).join(UserBlock, UserBlock.blocked_id == User.id).where(UserBlock.blocker_id == user.id)
    return list((await db.scalars(stmt)).all())
async def ensure_member(db: AsyncSession, conversation_id: int, user_id: int):
    return await db.scalar(select(ConversationMember.id).where(ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user_id))
@router.get("/conversations")
async def conversations(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ids = select(ConversationMember.conversation_id).where(ConversationMember.user_id == user.id)
    rows = await db.scalars(select(Conversation).where(Conversation.id.in_(ids)))
    return [{"id": c.id, "kind": c.kind, "title": c.title} for c in rows]
@router.get("/conversations/{conversation_id}/messages")
async def history(conversation_id: int, before_id: int | None = None, limit: int = Query(default=50, ge=1, le=100), user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    if not await ensure_member(db, conversation_id, user.id): raise HTTPException(403, "لست عضوًا في هذه المحادثة")
    stmt = select(Message).where(Message.conversation_id == conversation_id)
    if before_id: stmt = stmt.where(Message.id < before_id)
    rows = list((await db.scalars(stmt.order_by(Message.id.desc()).limit(limit))).all()); rows.reverse()
    return [{"id": m.id, "sender_id": m.sender_id, "kind": m.kind, "content": m.content, "reply_to_id": m.reply_to_id, "created_at": m.created_at} for m in rows]
