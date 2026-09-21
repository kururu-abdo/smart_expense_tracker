from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import auth, billing, expenses


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Masar • Smart Expense Tracker",
        version="1.0.0",
        docs_url="/docs" if settings.environment != "production" else None,
        redoc_url=None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
    )
    app.include_router(auth.router, prefix="/api/v1")
    app.include_router(expenses.router, prefix="/api/v1")
    app.include_router(billing.router, prefix="/api/v1")

    @app.get("/health")
    def health():
        return {"status": "ok", "service": "masar-api"}

    @app.middleware("http")
    async def secure_headers(request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cache-Control"] = "no-store"
        return response

    return app


app = create_app()
