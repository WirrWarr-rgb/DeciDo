from fastapi import APIRouter
from app.api.v1.endpoints import auth_router, lists_router, users_router

router = APIRouter(prefix="/api/v1")

router.include_router(auth_router)
router.include_router(lists_router)
router.include_router(users_router)