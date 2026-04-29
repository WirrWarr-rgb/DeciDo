import json
from typing import Optional
from fastapi import WebSocket, Query
from jose import jwt, JWTError
from sqlalchemy import select
from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.user import User
from app.websocket.manager import manager


async def global_websocket(
    websocket: WebSocket,
    token: Optional[str] = Query(None),
):
    """Глобальный WebSocket для уведомлений"""
    
    if not token:
        await websocket.close(code=4001)
        return
    
    if token.startswith("Bearer "):
        token = token[7:]
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email = payload.get("sub")
        if not email:
            await websocket.close(code=4001)
            return
    except JWTError:
        await websocket.close(code=4001)
        return
    
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if not user:
            await websocket.close(code=4001)
            return
        
        await websocket.accept()
        
        # Добавляем пользователя в глобальный список
        if 0 not in manager.local_connections:
            manager.local_connections[0] = {}
        manager.local_connections[0][user.id] = websocket
        print(f"✅ User {user.id} ({user.username}) connected to global WebSocket")
        
        try:
            while True:
                data = await websocket.receive_text()
                # Просто держим соединение открытым
        except:
            if 0 in manager.local_connections:
                manager.local_connections[0].pop(user.id, None)