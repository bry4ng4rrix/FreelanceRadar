from fastapi import APIRouter

from app.api.v1 import (
    applications,
    auth,
    health,
    notifications,
    offers,
    profile,
    replies,
    sources,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(sources.router)
api_router.include_router(offers.router)
api_router.include_router(profile.router)
api_router.include_router(notifications.router)
api_router.include_router(applications.router)
api_router.include_router(replies.router)
