# app/api/v1/endpoints/sessions_ws.py
import json
from typing import Optional

from fastapi import WebSocket, WebSocketDisconnect, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.websocket.manager import manager
from app.services.session_service import SessionService
from app.services.session_list_service import SessionListService
from app.schemas.session import WSMessageType


async def sessions_websocket(
    websocket: WebSocket,
    session_id: int,
    token: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """WebSocket эндпоинт для реального времени в сессии."""
    # Аутентификация
    from jose import jwt, JWTError
    from app.core.config import settings
    from app.models.user import User
    from sqlalchemy import select
    
    if not token:
        await websocket.close(code=4001, reason="Missing authentication token")
        return
    
    if token.startswith("Bearer "):
        token = token[7:]
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            await websocket.close(code=4001, reason="Invalid token")
            return
    except JWTError:
        await websocket.close(code=4001, reason="Invalid token")
        return
    
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    
    if user is None:
        await websocket.close(code=4001, reason="User not found")
        return
    
    await manager.initialize()
    
    session_service = SessionService(db)
    list_service = SessionListService(db)
    
    try:
        session_detail = await session_service.get_session_detail(session_id, user.id)
    except ValueError as e:
        await websocket.close(code=4003, reason=str(e))
        return
    
    await manager.connect(session_id, user.id, websocket)
    
    # Отправляем начальное состояние
    await manager.send_personal(
        session_id, user.id,
        {
            "type": WSMessageType.SESSION_STATE_CHANGED.value,
            "payload": session_detail
        }
    )
    
    try:
        while True:
            data = await websocket.receive_text()
            
            try:
                message_data = json.loads(data)
                msg_type = message_data.get("type")
                payload = message_data.get("payload", {})
            except json.JSONDecodeError:
                await manager.send_personal(
                    session_id, user.id,
                    {
                        "type": WSMessageType.ERROR.value,
                        "payload": {"message": "Invalid JSON"}
                    }
                )
                continue
            
            # Ping
            if msg_type == WSMessageType.PING.value:
                await manager.send_personal(
                    session_id, user.id,
                    {"type": WSMessageType.PONG.value, "payload": {}}
                )
            
            # Ready
            elif msg_type == WSMessageType.READY.value:
                try:
                    result = await session_service.mark_ready(session_id, user.id)
                    updated_detail = await session_service.get_session_detail(session_id, user.id)
                    
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": WSMessageType.USER_READY.value,
                            "payload": {
                                "user_id": user.id,
                                "username": user.username,
                                "participants": updated_detail["participants"]
                            }
                        }
                    )
                    
                    if result.get("countdown_started"):
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.COUNTDOWN_STARTED.value,
                                "payload": {
                                    "countdown_ends_at": updated_detail["countdown_ends_at"].isoformat() if updated_detail["countdown_ends_at"] else None
                                }
                            }
                        )
                    
                    if updated_detail["status"] == "voting":
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.SESSION_STATE_CHANGED.value,
                                "payload": updated_detail
                            }
                        )
                        
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user.id,
                        {
                            "type": WSMessageType.ERROR.value,
                            "payload": {"message": str(e)}
                        }
                    )
            
            # Vote
            elif msg_type == WSMessageType.VOTE.value:
                try:
                    ranked_ids = payload.get("ranked_item_ids")
                    spin = payload.get("spin", False)
                    
                    all_voted, results = await session_service.submit_vote(
                        session_id=session_id,
                        user_id=user.id,
                        ranked_item_ids=ranked_ids,
                        spin=spin
                    )
                    
                    updated_detail = await session_service.get_session_detail(session_id, user.id)
                    
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": WSMessageType.USER_VOTED.value,
                            "payload": {
                                "user_id": user.id,
                                "username": user.username,
                                "participants": updated_detail["participants"]
                            }
                        }
                    )
                    
                    if all_voted and results:
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.RESULTS_READY.value,
                                "payload": results
                            }
                        )
                        
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user.id,
                        {
                            "type": WSMessageType.ERROR.value,
                            "payload": {"message": str(e)}
                        }
                    )
            
            # Add list item
            elif msg_type == WSMessageType.ADD_LIST_ITEM.value:
                try:
                    name = payload.get("name")
                    description = payload.get("description")
                    image_url = payload.get("image_url")
                    
                    item = await list_service.add_item(
                        session_id=session_id,
                        user_id=user.id,
                        name=name,
                        description=description,
                        image_url=image_url
                    )
                    
                    creator_name = await list_service.get_item_creator_name(item)
                    
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": WSMessageType.LIST_ITEM_ADDED.value,
                            "payload": {
                                "item": {
                                    "id": item.id,
                                    "name": item.name,
                                    "description": item.description,
                                    "image_url": item.image_url,
                                    "order_index": item.order_index,
                                    "created_by": item.created_by,
                                    "creator_name": creator_name
                                }
                            }
                        }
                    )
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user.id,
                        {
                            "type": WSMessageType.ERROR.value,
                            "payload": {"message": str(e)}
                        }
                    )
            
            # Update list item
            elif msg_type == WSMessageType.UPDATE_LIST_ITEM.value:
                try:
                    item_id = payload.get("item_id")
                    name = payload.get("name")
                    description = payload.get("description")
                    image_url = payload.get("image_url")
                    
                    item = await list_service.update_item(
                        session_id=session_id,
                        item_id=item_id,
                        user_id=user.id,
                        name=name,
                        description=description,
                        image_url=image_url
                    )
                    
                    creator_name = await list_service.get_item_creator_name(item)
                    
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": WSMessageType.LIST_ITEM_UPDATED.value,
                            "payload": {
                                "item": {
                                    "id": item.id,
                                    "name": item.name,
                                    "description": item.description,
                                    "image_url": item.image_url,
                                    "order_index": item.order_index,
                                    "created_by": item.created_by,
                                    "creator_name": creator_name
                                }
                            }
                        }
                    )
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user.id,
                        {
                            "type": WSMessageType.ERROR.value,
                            "payload": {"message": str(e)}
                        }
                    )
            
            # Delete list item
            elif msg_type == WSMessageType.DELETE_LIST_ITEM.value:
                try:
                    item_id = payload.get("item_id")
                    await list_service.delete_item(session_id, item_id)
                    
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": WSMessageType.LIST_ITEM_DELETED.value,
                            "payload": {"item_id": item_id}
                        }
                    )
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user.id,
                        {
                            "type": WSMessageType.ERROR.value,
                            "payload": {"message": str(e)}
                        }
                    )
            
            # Update item order
            elif msg_type == WSMessageType.UPDATE_ITEM_ORDER.value:
                try:
                    items_order = payload.get("items", [])
                    items = await list_service.update_order(session_id, items_order)
                    
                    items_data = []
                    for item in items:
                        creator_name = await list_service.get_item_creator_name(item)
                        items_data.append({
                            "id": item.id,
                            "name": item.name,
                            "description": item.description,
                            "image_url": item.image_url,
                            "order_index": item.order_index,
                            "created_by": item.created_by,
                            "creator_name": creator_name
                        })
                    
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": WSMessageType.LIST_UPDATED.value,
                            "payload": {"items": items_data}
                        }
                    )
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user.id,
                        {
                            "type": WSMessageType.ERROR.value,
                            "payload": {"message": str(e)}
                        }
                    )
            
            else:
                await manager.send_personal(
                    session_id, user.id,
                    {
                        "type": WSMessageType.ERROR.value,
                        "payload": {"message": f"Unknown message type: {msg_type}"}
                    }
                )
                
    except WebSocketDisconnect:
        manager.disconnect(session_id, user.id)
        
        # Если это был создатель и он вышел - можно удалить сессию
        # (опционально, можно реализовать отложенное удаление)