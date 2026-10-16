from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.models import User
from app.security import decode_access_token
bearer = HTTPBearer(auto_error=False)
async def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), db: AsyncSession = Depends(get_db)) -> User:
    if credentials is None: raise HTTPException(status_code=401, detail="Authentication required")
    user_id = decode_access_token(credentials.credentials)
    user = await db.scalar(select(User).where(User.id == user_id, User.is_active.is_(True)))
    if user is None: raise HTTPException(status_code=401, detail="Account unavailable")
    return user
