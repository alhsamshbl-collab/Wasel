import asyncio
from collections import defaultdict
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from sqlalchemy import select
from app.database.session import SessionLocal
from app.models import ConversationMember, Message
from app.security import decode_access_token

router = APIRouter()
_connections: dict[int, set[WebSocket]] = defaultdict(set)
_lock = asyncio.Lock()

async def broadcast(conversation_id: int, payload: dict) -> None:
    async with _lock:
        peers = list(_connections.get(conversation_id, set()))
    dead = []
    for peer in peers:
        try:
            await peer.send_json(payload)
        except Exception:
            dead.append(peer)
    if dead:
        async with _lock:
            for peer in dead:
                _connections[conversation_id].discard(peer)

@router.websocket("/ws/conversations/{conversation_id}")
async def conversation_socket(websocket: WebSocket, conversation_id: int, token: str):
    try:
        user_id = decode_access_token(token)
    except HTTPException:
        await websocket.close(code=4401, reason="Unauthorized")
        return
    async with SessionLocal() as db:
        member = await db.scalar(select(ConversationMember.id).where(
            ConversationMember.conversation_id == conversation_id,
            ConversationMember.user_id == user_id))
    if not member:
        await websocket.close(code=4403, reason="Not a conversation member")
        return
    await websocket.accept()
    async with _lock:
        _connections[conversation_id].add(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            content = str(data.get("content", "")).strip()
            if not content or len(content) > 5000:
                await websocket.send_json({"type": "error", "detail": "الرسالة مطلوبة وبحد أقصى 5000 حرف"})
                continue
            async with SessionLocal() as db:
                member = await db.scalar(select(ConversationMember.id).where(
                    ConversationMember.conversation_id == conversation_id,
                    ConversationMember.user_id == user_id))
                if not member:
                    await websocket.close(code=4403, reason="Membership removed")
                    return
                message = Message(conversation_id=conversation_id, sender_id=user_id, kind="text", content=content)
                db.add(message)
                await db.commit()
                await db.refresh(message)
                payload = {"type": "message", "id": message.id, "conversation_id": conversation_id,
                           "sender_id": user_id, "kind": message.kind, "content": message.content,
                           "created_at": message.created_at.isoformat()}
            await broadcast(conversation_id, payload)
    except WebSocketDisconnect:
        pass
    finally:
        async with _lock:
            _connections[conversation_id].discard(websocket)
            if not _connections[conversation_id]:
                _connections.pop(conversation_id, None)
