# app/api/v1/endpoints/sessions.py
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.session import SessionStatus, SessionMode, ParticipantStatus

from app.core.database import get_db
from app.models.user import User
from app.api.v1.endpoints.auth import get_current_user
from app.services.session_service import SessionService
from app.services.session_list_service import SessionListService
from app.schemas.session import (
    CreateLobbyRequest, LobbyResponse, MyLobbiesResponse,
    AcceptInviteRequest, DeclineInviteRequest,
    MarkReadyRequest, StartLobbyRequest,
    ChangeListRequest, LockListRequest, UnlockListRequest,
    VoteRequest, VoteResultResponse, ResultsResponse,
    SessionListItemCreate, SessionListItemUpdate, SessionListItemResponse,
    ItemsOrderUpdate, InviteToLobbyRequest
)
from app.websocket.manager import manager

router = APIRouter(prefix="/sessions", tags=["sessions"])


# ============= Лобби =============

@router.post("/", response_model=LobbyResponse, status_code=status.HTTP_201_CREATED)
async def create_lobby(
    request: CreateLobbyRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Создать новое лобби"""
    service = SessionService(db)
    
    try:
        items_data = [
            {
                "name": item.name,
                "description": item.description,
                "image_url": item.image_url,
                "order_index": item.order_index
            }
            for item in request.list_data.items
        ]
        
        session = await service.create_lobby(
            owner_id=current_user.id,
            friend_ids=request.friend_ids,
            list_name=request.list_data.name,
            list_items=items_data,
            mode=request.mode,
            voting_duration=request.voting_duration
        )
        
        for friend_id in request.friend_ids:
            await manager.send_to_user(
                friend_id,
                {
                    "type": "navigate_to_lobby",
                    "payload": {
                        "session_id": session.id,
                        "owner_name": current_user.username
                    }
                }
            )
        
        return await service.get_lobby(session.id, current_user.id)
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/my", response_model=MyLobbiesResponse)
async def get_my_lobbies(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить все мои лобби"""
    service = SessionService(db)
    return await service.get_my_lobbies(current_user.id)


@router.get("/{session_id}", response_model=LobbyResponse)
async def get_lobby(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить информацию о лобби"""
    service = SessionService(db)
    
    try:
        return await service.get_lobby(session_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post("/{session_id}/accept")
async def accept_invite(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Принять приглашение в лобби"""
    service = SessionService(db)
    
    try:
        participant = await service.accept_invite(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "participant_joined",
                "payload": {
                    "user_id": current_user.id,
                    "username": current_user.username
                }
            }
        )
        
        return {"success": True, "status": participant.status.value}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/decline")
async def decline_invite(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отклонить приглашение"""
    service = SessionService(db)
    
    try:
        await service.decline_invite(session_id, current_user.id)
        return {"success": True}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/leave")
async def leave_lobby(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Выйти из лобби"""
    service = SessionService(db)
    
    try:
        result = await service.leave_lobby(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "participant_left",
                "payload": {
                    "user_id": current_user.id,
                    "username": current_user.username,
                    "lobby_closed": result["lobby_closed"]
                }
            }
        )
        
        if result["lobby_closed"]:
            await manager.broadcast_to_session(
                session_id,
                {
                    "type": "lobby_closed",
                    "payload": {"session_id": session_id}
                }
            )
        
        return result
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/close")
async def close_lobby(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Закрыть лобби (только владелец)"""
    service = SessionService(db)
    
    try:
        await service.close_lobby(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "lobby_closed",
                "payload": {"session_id": session_id}
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/invite")
async def invite_friends(
    session_id: int,
    request: InviteToLobbyRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Пригласить ещё друзей (только владелец)"""
    service = SessionService(db)
    
    try:
        participants = await service.invite_friends(
            session_id, current_user.id, request.friend_ids
        )
        
        for p in participants:
            await manager.send_to_user(
                p.user_id,
                {
                    "type": "navigate_to_lobby",
                    "payload": {
                        "session_id": session_id,
                        "owner_name": current_user.username
                    }
                }
            )
        
        return {"invited": len(participants)}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ============= Управление списком =============

@router.post("/{session_id}/list/change")
async def change_list(
    session_id: int,
    request: ChangeListRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Сменить список (только владелец)"""
    service = SessionService(db)
    
    try:
        new_list = await service.change_list(session_id, current_user.id, request.list_id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "list_changed",
                "payload": {"list_id": new_list.id, "list_name": new_list.name}
            }
        )
        
        return {"success": True, "list_id": new_list.id}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/list/lock")
async def lock_list(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Заблокировать список (только владелец)"""
    service = SessionService(db)
    
    try:
        await service.lock_list(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {"type": "list_locked", "payload": {}}
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/list/unlock")
async def unlock_list(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Разблокировать список (только владелец)"""
    service = SessionService(db)
    
    try:
        await service.unlock_list(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {"type": "list_unlocked", "payload": {}}
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ============= Пункты списка =============

@router.post("/{session_id}/list/items", response_model=SessionListItemResponse)
async def add_item(
    session_id: int,
    request: SessionListItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Добавить пункт в список"""
    list_service = SessionListService(db)
    
    try:
        item = await list_service.add_item(
            session_id, current_user.id,
            request.name, request.description, request.image_url
        )
        
        creator_name = await list_service.get_creator_name(item)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "list_item_added",
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
        
        return {
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "image_url": item.image_url,
            "order_index": item.order_index,
            "created_by": item.created_by,
            "creator_name": creator_name
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/{session_id}/list/items/{item_id}", response_model=SessionListItemResponse)
async def update_item(
    session_id: int,
    item_id: int,
    request: SessionListItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить пункт"""
    list_service = SessionListService(db)
    
    try:
        item = await list_service.update_item(
            session_id, item_id,
            request.name, request.description, request.image_url
        )
        
        creator_name = await list_service.get_creator_name(item)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "list_item_updated",
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
        
        return {
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "image_url": item.image_url,
            "order_index": item.order_index,
            "created_by": item.created_by,
            "creator_name": creator_name
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{session_id}/list/items/{item_id}")
async def delete_item(
    session_id: int,
    item_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить пункт"""
    list_service = SessionListService(db)
    
    try:
        await list_service.delete_item(session_id, item_id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "list_item_deleted",
                "payload": {"item_id": item_id}
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/{session_id}/list/items/order")
async def update_order(
    session_id: int,
    request: ItemsOrderUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить порядок пунктов"""
    list_service = SessionListService(db)
    
    try:
        items = await list_service.update_order(session_id, request.items)
        
        items_data = []
        for item in items:
            creator_name = await list_service.get_creator_name(item)
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
                "type": "list_order_changed",
                "payload": {"items": items_data}
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ============= Готовность и старт =============

@router.post("/{session_id}/ready")
async def mark_ready(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отметить готовность"""
    service = SessionService(db)
    
    try:
        await service.mark_ready(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "participant_ready",
                "payload": {
                    "user_id": current_user.id,
                    "username": current_user.username
                }
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/start")
async def force_start(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Принудительно начать (только владелец)"""
    service = SessionService(db)
    
    try:
        session = await service.force_start(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "voting_started",
                "payload": {
                    "voting_ends_at": session.voting_ends_at.isoformat() if session.voting_ends_at else None
                }
            }
        )
        
        return {"success": True, "status": session.status.value}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ============= Голосование =============

@router.post("/{session_id}/vote", response_model=VoteResultResponse)
async def submit_vote(
    session_id: int,
    request: VoteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отправить голос"""
    service = SessionService(db)
    
    try:
        all_voted, results = await service.submit_vote(
            session_id, current_user.id,
            request.ranked_item_ids, request.spin
        )
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "user_voted",
                "payload": {
                    "user_id": current_user.id,
                    "username": current_user.username
                }
            }
        )
        
        if all_voted and results:
            await manager.broadcast_to_session(
                session_id,
                {
                    "type": "results_ready",
                    "payload": results
                }
            )
        
        return VoteResultResponse(
            success=True,
            message="Vote submitted",
            all_voted=all_voted
        )
        
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.post("/{session_id}/back-to-lobby")
async def back_to_lobby(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Вернуться в лобби после результатов (только владелец)"""
    service = SessionService(db)
    
    try:
        session = await service.back_to_lobby(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "state_changed",
                "payload": {"status": session.status.value}
            }
        )
        
        return {"success": True, "status": session.status.value}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
@router.post("/{session_id}/unready")
async def mark_unready(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отменить готовность"""
    service = SessionService(db)
    
    try:
        participant = await service.mark_unready(session_id, current_user.id)
        
        lobby = await service.get_lobby(session_id, current_user.id)
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "timer_updated",
                "payload": {
                    "countdown_ends_at": lobby["countdown_ends_at"].isoformat() if lobby.get("countdown_ends_at") else None,
                    "participants": lobby["participants"]
                }
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/kick/{user_id}")
async def kick_participant(
    session_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Изгнать участника (только хост)"""
    service = SessionService(db)
    
    try:
        await service.kick_participant(session_id, current_user.id, user_id)
        
        # Уведомляем изгнанного
        await manager.send_to_user(
            user_id,
            {
                "type": "navigate_to_home",
                "payload": {"reason": "kicked", "lobby_id": session_id}
            }
        )
        
        # Уведомляем остальных
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "participant_kicked",
                "payload": {"user_id": user_id}
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{session_id}/list/items/{item_id}/lock")
async def lock_item(
    session_id: int,
    item_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Заблокировать элемент для редактирования"""
    service = SessionService(db)
    
    try:
        item = await service.lock_item_for_edit(item_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "item_locked",
                "payload": {
                    "item_id": item_id,
                    "edited_by": current_user.id,
                    "editor_name": current_user.username
                }
            }
        )
        
        return {"success": True, "item_id": item_id}
        
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))


@router.post("/{session_id}/list/items/{item_id}/unlock")
async def unlock_item(
    session_id: int,
    item_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Разблокировать элемент"""
    service = SessionService(db)
    
    try:
        await service.unlock_item(item_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "item_unlocked",
                "payload": {"item_id": item_id}
            }
        )
        
        return {"success": True}
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{session_id}/results")
async def get_results(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить результаты"""
    service = SessionService(db)
    
    session = await service._get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Исправлено — теперь SessionStatus доступен
    if session.status not in [SessionStatus.RESULTS, SessionStatus.CLOSED]:
        raise HTTPException(status_code=400, detail="Results not ready")
    
    return session.results_json