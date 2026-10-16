from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.routes import router

app = FastAPI(title="واصل | Wasel API", description="واجهة API لتطبيق واصل", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origin_list, allow_credentials=True,
                   allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
                   allow_headers=["Authorization", "Content-Type"])
app.include_router(router, prefix="/api")

@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "service": "wasel-api"}
