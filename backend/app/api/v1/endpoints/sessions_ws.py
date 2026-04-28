# app/api/v1/endpoints/sessions_ws.py
import json
from typing import Optional

from fastapi import WebSocket, WebSocketDisconnect, Query
from app.core.database import AsyncSessionLocal
from app.websocket.manager import manager
from app.services.session_service import SessionService
from app.services.session_list_service import SessionListService
from app.schemas.session import WSMessageType


async def sessions_websocket(
    websocket: WebSocket,
    session_id: int,
    token: Optional[str] = Query(None),
):
    """WebSocket для лобби"""
    
    # Аутентификация - создаём сессию БД
    from jose import jwt, JWTError
    from app.core.config import settings
    from app.models.user import User
    from sqlalchemy import select
    
    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return
    
    if token.startswith("Bearer "):
        token = token[7:]
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email = payload.get("sub")
        if not email:
            await websocket.close(code=4001, reason="Invalid token")
            return
    except JWTError:
        await websocket.close(code=4001, reason="Invalid token")
        return
    
    # Получаем пользователя из БД
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if not user:
            await websocket.close(code=4001, reason="User not found")
            return
        
        await websocket.accept()
        await manager.initialize()
        
        service = SessionService(db)
        list_service = SessionListService(db)
        
        # Проверяем доступ
        try:
            await service.get_lobby(session_id, user.id)
        except ValueError as e:
            await websocket.close(code=4003, reason=str(e))
            return
        
        await manager.connect(session_id, user.id, websocket)
        
        # Отправляем текущее состояние
        lobby = await service.get_lobby(session_id, user.id)
        await manager.send_personal(
            session_id, user.id,
            {"type": WSMessageType.STATE_CHANGED.value, "payload": lobby}
        )
    
    # Основной цикл обработки сообщений (вне контекста db)
    try:
        while True:
            data = await websocket.receive_text()
            
            try:
                msg = json.loads(data)
                msg_type = msg.get("type")
                payload = msg.get("payload", {})
            except json.JSONDecodeError:
                await manager.send_personal(
                    session_id, user.id,
                    {"type": WSMessageType.ERROR.value, "payload": {"message": "Invalid JSON"}}
                )
                continue
            
            # Для каждого запроса создаём новую сессию БД
            async with AsyncSessionLocal() as db:
                service = SessionService(db)
                list_service = SessionListService(db)
                
                # Ping
                if msg_type == WSMessageType.PING.value:
                    await manager.send_personal(
                        session_id, user.id,
                        {"type": WSMessageType.PONG.value, "payload": {}}
                    )
                
                # Принять приглашение
                elif msg_type == WSMessageType.ACCEPT_INVITE.value:
                    try:
                        await service.accept_invite(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.PARTICIPANT_JOINED.value,
                                "payload": {"user_id": user.id, "username": user.username}
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Отклонить приглашение
                elif msg_type == WSMessageType.DECLINE_INVITE.value:
                    try:
                        await service.decline_invite(session_id, user.id)
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Готовность
                elif msg_type == WSMessageType.READY.value:
                    try:
                        await service.mark_ready(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.PARTICIPANT_READY.value,
                                "payload": {"user_id": user.id, "username": user.username}
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Старт (владелец)
                elif msg_type == WSMessageType.START_LOBBY.value:
                    try:
                        session = await service.force_start(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.VOTING_STARTED.value,
                                "payload": {
                                    "voting_ends_at": session.voting_ends_at.isoformat() if session.voting_ends_at else None
                                }
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Сменить список (владелец)
                elif msg_type == WSMessageType.CHANGE_LIST.value:
                    try:
                        list_id = payload.get("list_id")
                        new_list = await service.change_list(session_id, user.id, list_id)
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.LIST_CHANGED.value,
                                "payload": {"list_id": new_list.id, "list_name": new_list.name}
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Заблокировать список (владелец)
                elif msg_type == WSMessageType.LOCK_LIST.value:
                    try:
                        await service.lock_list(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LIST_LOCKED.value, "payload": {}}
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Разблокировать список (владелец)
                elif msg_type == WSMessageType.UNLOCK_LIST.value:
                    try:
                        await service.unlock_list(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LIST_UNLOCKED.value, "payload": {}}
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Добавить пункт
                elif msg_type == WSMessageType.ADD_ITEM.value:
                    try:
                        item = await list_service.add_item(
                            session_id, user.id,
                            payload.get("name"),
                            payload.get("description"),
                            payload.get("image_url")
                        )
                        creator_name = await list_service.get_creator_name(item)
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
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Обновить пункт
                elif msg_type == WSMessageType.UPDATE_ITEM.value:
                    try:
                        item = await list_service.update_item(
                            session_id, payload.get("item_id"),
                            payload.get("name"),
                            payload.get("description"),
                            payload.get("image_url")
                        )
                        creator_name = await list_service.get_creator_name(item)
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
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Удалить пункт
                elif msg_type == WSMessageType.DELETE_ITEM.value:
                    try:
                        await list_service.delete_item(session_id, payload.get("item_id"))
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.LIST_ITEM_DELETED.value,
                                "payload": {"item_id": payload.get("item_id")}
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Обновить порядок
                elif msg_type == WSMessageType.UPDATE_ORDER.value:
                    try:
                        items = await list_service.update_order(session_id, payload.get("items", []))
                        items_data = []
                        for item in items:
                            creator_name = await list_service.get_creator_name(item)
                            items_data.append({
                                "id": item.id,
                                "name": item.name,
                                "order_index": item.order_index,
                                "creator_name": creator_name
                            })
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.LIST_ORDER_CHANGED.value,
                                "payload": {"items": items_data}
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Голосование
                elif msg_type == WSMessageType.VOTE.value:
                    try:
                        all_voted, results = await service.submit_vote(
                            session_id, user.id,
                            payload.get("ranked_item_ids"),
                            payload.get("spin", False)
                        )
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.USER_VOTED.value,
                                "payload": {"user_id": user.id, "username": user.username}
                            }
                        )
                        if all_voted and results:
                            await manager.broadcast_to_session(
                                session_id,
                                {"type": WSMessageType.RESULTS_READY.value, "payload": results}
                            )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Выйти из лобби
                elif msg_type == WSMessageType.LEAVE_LOBBY.value:
                    try:
                        result = await service.leave_lobby(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.PARTICIPANT_LEFT.value,
                                "payload": {
                                    "user_id": user.id,
                                    "username": user.username,
                                    "lobby_closed": result["lobby_closed"]
                                }
                            }
                        )
                        if result["lobby_closed"]:
                            await manager.broadcast_to_session(
                                session_id,
                                {"type": WSMessageType.LOBBY_CLOSED.value, "payload": {"session_id": session_id}}
                            )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Закрыть лобби (владелец)
                elif msg_type == WSMessageType.CLOSE_LOBBY.value:
                    try:
                        await service.close_lobby(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LOBBY_CLOSED.value, "payload": {"session_id": session_id}}
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Вернуться в лобби (владелец)
                elif msg_type == WSMessageType.BACK_TO_LOBBY.value:
                    try:
                        session = await service.back_to_lobby(session_id, user.id)
                        await manager.broadcast_to_session(
                            session_id,
                            {
                                "type": WSMessageType.STATE_CHANGED.value,
                                "payload": {"status": session.status.value}
                            }
                        )
                    except ValueError as e:
                        await manager.send_personal(
                            session_id, user.id,
                            {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                        )
                
                # Неизвестный тип
                else:
                    await manager.send_personal(
                        session_id, user.id,
                        {"type": WSMessageType.ERROR.value, "payload": {"message": f"Unknown type: {msg_type}"}}
                    )
                
    except WebSocketDisconnect:
        manager.disconnect(session_id, user.id)