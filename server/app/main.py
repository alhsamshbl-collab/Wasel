from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.routes import router
from app.conversation_routes import router as conversation_router
from app.realtime import router as realtime_router

app = FastAPI(title="واصل | Wasel API", description="واجهة API لتطبيق واصل", version="0.2.0")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origin_list, allow_credentials=True,
                   allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
                   allow_headers=["Authorization", "Content-Type"])
app.include_router(router, prefix="/api")
app.include_router(conversation_router, prefix="/api")
app.include_router(realtime_router)

@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "service": "wasel-api"}
