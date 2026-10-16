from datetime import datetime, timedelta, timezone
import jwt
from pwdlib import PasswordHash
from fastapi import HTTPException
from app.core.config import settings

password_hash = PasswordHash.recommended()

def hash_password(password: str) -> str:
    return password_hash.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    try:
        return password_hash.verify(password, hashed)
    except Exception:
        return False

def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": str(user_id), "iat": now, "exp": now + timedelta(minutes=settings.jwt_access_minutes), "type": "access"}, settings.jwt_secret, algorithm="HS256")

def decode_access_token(token: str) -> int:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        if payload.get("type") != "access":
            raise ValueError("wrong token type")
        return int(payload["sub"])
    except Exception as exc:
        raise HTTPException(status_code=401, detail="جلسة غير صالحة أو منتهية") from exc
