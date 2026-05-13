import json
from typing import Optional
from fastapi import WebSocket, WebSocketDisconnect, Query
from app.core.database import AsyncSessionLocal
from app.websocket.manager import manager
from app.services.session_service import SessionService
from app.services.session_list_service import SessionListService
from app.schemas.session import WSMessageType
import asyncio

async def sessions_websocket(
    websocket: WebSocket,
    session_id: int,
    token: Optional[str] = Query(None),
):
    """WebSocket для лобби"""
    
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
    
    # Получаем пользователя в ОДНОЙ сессии
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if not user:
            await websocket.close(code=4001, reason="User not found")
            return
        
        service = SessionService(db)
        try:
            await service.get_lobby(session_id, user.id)
        except ValueError as e:
            await websocket.close(code=4003, reason=str(e))
            return
        
        user_id = user.id
        username = user.username
    
    # Принимаем соединение
    await websocket.accept()
    print(f"✅ WebSocket accepted for user {user_id}, session {session_id}")
    
    # Инициализируем менеджер
    await manager.initialize()
    
    # Подключаем в менеджер (только один раз!)
    await manager.connect(session_id, user_id, websocket)
    print(f"✅ User {user_id} connected to manager for session {session_id}")
    
    # Отправляем начальное состояние
    try:
        async with AsyncSessionLocal() as db:
            service = SessionService(db)
            lobby = await service.get_lobby(session_id, user_id)
            await manager.send_personal(
                session_id, user_id,
                {"type": WSMessageType.STATE_CHANGED.value, "payload": lobby}
            )
            print(f"✅ Initial state sent to user {user_id}")
    except Exception as e:
        print(f"❌ Failed to send initial state: {e}")
    
    # Переподключаемся
    await manager.connect(session_id, user_id, websocket)
    
    print(f"🔵 Entering message loop for user {user_id}, session {session_id}")
    
    # Основной цикл
    try:
        while True:
            try:
                data = await websocket.receive_text()
            except WebSocketDisconnect:
                print(f"🔴 User {user_id} disconnected (WebSocketDisconnect)")
                break
                
            print(f"📨 Received message from user {user_id}: {data[:100]}...")
            
            try:
                msg = json.loads(data)
                msg_type = msg.get("type")
                payload = msg.get("payload", {})
            except json.JSONDecodeError:
                await manager.send_personal(
                    session_id, user_id,
                    {"type": WSMessageType.ERROR.value, "payload": {"message": "Invalid JSON"}}
                )
                continue
            
            # Обрабатываем сообщение
            async with AsyncSessionLocal() as db:
                service = SessionService(db)
                list_service = SessionListService(db)
                
                try:
                    if msg_type == WSMessageType.PING.value:
                        await manager.send_personal(
                            session_id, user_id,
                            {"type": WSMessageType.PONG.value, "payload": {}}
                        )
                    
                    elif msg_type == WSMessageType.READY.value:
                        await service.mark_ready(session_id, user_id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.PARTICIPANT_READY.value,
                             "payload": {"user_id": user_id, "username": username}}
                        )
                    
                    elif msg_type == WSMessageType.UNREADY.value:
                        await service.mark_unready(session_id, user_id)
                        lobby = await service.get_lobby(session_id, user_id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": "timer_updated",
                             "payload": {
                                 "countdown_ends_at": lobby["countdown_ends_at"].isoformat() if lobby.get("countdown_ends_at") else None,
                                 "participants": lobby["participants"]
                             }}
                        )
                    
                    elif msg_type == WSMessageType.START_VOTING.value:
                        session = await service.force_start(session_id, user_id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.VOTING_STARTED.value,
                             "payload": {"voting_ends_at": session.voting_ends_at.isoformat() if session.voting_ends_at else None}}
                        )
                    
                    elif msg_type == WSMessageType.ADD_ITEM.value:
                        item = await list_service.add_item(
                            session_id, user_id,
                            payload.get("name"),
                            payload.get("description"),
                            payload.get("image_url")
                        )
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LIST_ITEM_ADDED.value,
                             "payload": {"item": {
                                 "id": item.id, "name": item.name,
                                 "description": item.description,
                                 "image_url": item.image_url,
                                 "order_index": item.order_index,
                                 "created_by": item.created_by,
                                 "creator_name": await list_service.get_creator_name(item)
                             }}}
                        )
                    
                    elif msg_type == WSMessageType.UPDATE_ITEM.value:
                        item = await list_service.update_item(
                            session_id, payload.get("item_id"),
                            payload.get("name"),
                            payload.get("description"),
                            payload.get("image_url")
                        )
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LIST_ITEM_UPDATED.value,
                             "payload": {"item": {
                                 "id": item.id, "name": item.name,
                                 "description": item.description,
                                 "image_url": item.image_url,
                                 "order_index": item.order_index,
                                 "created_by": item.created_by,
                                 "creator_name": await list_service.get_creator_name(item)
                             }}}
                        )
                    
                    elif msg_type == WSMessageType.DELETE_ITEM.value:
                        await list_service.delete_item(session_id, payload.get("item_id"))
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LIST_ITEM_DELETED.value,
                             "payload": {"item_id": payload.get("item_id")}}
                        )
                    
                    elif msg_type == WSMessageType.VOTE.value:
                        all_voted, results = await service.submit_vote(
                            session_id, user_id,
                            payload.get("ranked_item_ids"),
                            payload.get("spin", False)
                        )
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.USER_VOTED.value,
                             "payload": {"user_id": user_id, "username": username}}
                        )
                        if all_voted and results:
                            await manager.broadcast_to_session(
                                session_id,
                                {"type": WSMessageType.RESULTS_READY.value, "payload": results}
                            )
                    
                    elif msg_type == WSMessageType.LEAVE_LOBBY.value:
                        result = await service.leave_lobby(session_id, user_id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.PARTICIPANT_LEFT.value,
                             "payload": {"user_id": user_id, "username": username,
                                        "lobby_closed": result["lobby_closed"]}}
                        )
                        if result["lobby_closed"]:
                            await manager.broadcast_to_session(
                                session_id,
                                {"type": WSMessageType.LOBBY_CLOSED.value,
                                 "payload": {"session_id": session_id}}
                            )
                        break  # Выходим из цикла
                    
                    elif msg_type == WSMessageType.CLOSE_LOBBY.value:
                        await service.close_lobby(session_id, user_id)
                        await manager.broadcast_to_session(
                            session_id,
                            {"type": WSMessageType.LOBBY_CLOSED.value,
                             "payload": {"session_id": session_id}}
                        )
                        await asyncio.sleep(0.5)
                        break
                    
                    else:
                        await manager.send_personal(
                            session_id, user_id,
                            {"type": WSMessageType.ERROR.value,
                             "payload": {"message": f"Unknown type: {msg_type}"}}
                        )
                        
                except ValueError as e:
                    await manager.send_personal(
                        session_id, user_id,
                        {"type": WSMessageType.ERROR.value, "payload": {"message": str(e)}}
                    )
                    
    except Exception as e:
        print(f"💥 Error in message loop: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
    finally:
        print(f"🔴 Disconnecting user {user_id} from session {session_id}")
        manager.disconnect(session_id, user_id)