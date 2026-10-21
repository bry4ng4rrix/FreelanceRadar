from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import Settings, get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        # Documentation interactive désactivée en production (exposition publique).
        docs_url=None if settings.environment == "production" else "/docs",
        redoc_url=None,
    )
    if settings.cors_origins:
        # Liste explicite uniquement : jamais de "*" avec des en-têtes d'authentification.
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_methods=["GET", "POST", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type"],
        )
    register_exception_handlers(app)
    app.dependency_overrides[get_settings] = lambda: settings
    app.include_router(api_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
