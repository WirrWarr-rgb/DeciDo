# app/api/v1/endpoints/sessions.py
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.user import User
from app.api.v1.endpoints.auth import get_current_user
from app.services.session_service import SessionService
from app.services.session_list_service import SessionListService
from app.schemas.session import (
    SessionCreate, SessionResponse, SessionDetailResponse,
    ReadyRequest, VoteRequest, VoteResultResponse, SessionResultsResponse,
    SessionListItemCreate, SessionListItemUpdate, SessionListItemResponse,
    SessionListResponse, SessionListOrderUpdate, ResetSessionRequest
)
from app.websocket.manager import manager

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("/", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    session_data: SessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Создать новую сессию голосования в группе.
    
    - **group_id**: ID группы
    - **list_id**: ID оригинального списка пользователя (будет скопирован)
    - **mode**: "random" или "ranking"
    - **countdown_duration**: время после первого "Готов" (сек)
    - **voting_duration**: время на голосование (сек)
    """
    session_service = SessionService(db)
    
    try:
        session = await session_service.create_session(
            group_id=session_data.group_id,
            original_list_id=session_data.list_id,
            mode=session_data.mode,
            created_by=current_user.id,
            countdown_duration=session_data.countdown_duration,
            voting_duration=session_data.voting_duration
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    
    return session


@router.get("/{session_id}", response_model=SessionDetailResponse)
async def get_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить детальную информацию о сессии."""
    session_service = SessionService(db)
    
    try:
        session_detail = await session_service.get_session_detail(session_id, current_user.id)
        return session_detail
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )


@router.get("/{session_id}/list", response_model=SessionListResponse)
async def get_session_list(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить временный список сессии."""
    list_service = SessionListService(db)
    
    # Проверяем, что пользователь участник
    session_service = SessionService(db)
    await session_service._get_participant(session_id, current_user.id)
    
    session_list = await list_service.get_session_list(session_id)
    if not session_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session list not found"
        )
    
    # Добавляем имена создателей
    items_data = []
    for item in session_list.items:
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
    
    return {
        "id": session_list.id,
        "session_id": session_list.session_id,
        "name": session_list.name,
        "items": items_data,
        "created_at": session_list.created_at,
        "updated_at": session_list.updated_at
    }


@router.post("/{session_id}/list/items", response_model=SessionListItemResponse)
async def add_session_list_item(
    session_id: int,
    item_data: SessionListItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Добавить пункт во временный список сессии."""
    list_service = SessionListService(db)
    
    # Проверяем, что пользователь участник
    session_service = SessionService(db)
    participant = await session_service._get_participant(session_id, current_user.id)
    
    # Проверяем, что не нажал "Готов"
    if participant.is_ready:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot edit list after marking ready"
        )
    
    try:
        item = await list_service.add_item(
            session_id=session_id,
            user_id=current_user.id,
            name=item_data.name,
            description=item_data.description,
            image_url=item_data.image_url
        )
        
        # Уведомляем всех через WebSocket
        creator_name = await list_service.get_item_creator_name(item)
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.put("/{session_id}/list/items/{item_id}", response_model=SessionListItemResponse)
async def update_session_list_item(
    session_id: int,
    item_id: int,
    item_data: SessionListItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить пункт временного списка."""
    list_service = SessionListService(db)
    
    # Проверяем, что пользователь участник
    session_service = SessionService(db)
    participant = await session_service._get_participant(session_id, current_user.id)
    
    if participant.is_ready:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot edit list after marking ready"
        )
    
    try:
        item = await list_service.update_item(
            session_id=session_id,
            item_id=item_id,
            user_id=current_user.id,
            name=item_data.name,
            description=item_data.description,
            image_url=item_data.image_url
        )
        
        creator_name = await list_service.get_item_creator_name(item)
        
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.delete("/{session_id}/list/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session_list_item(
    session_id: int,
    item_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить пункт из временного списка."""
    list_service = SessionListService(db)
    
    session_service = SessionService(db)
    participant = await session_service._get_participant(session_id, current_user.id)
    
    if participant.is_ready:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot edit list after marking ready"
        )
    
    try:
        await list_service.delete_item(session_id, item_id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "list_item_deleted",
                "payload": {"item_id": item_id}
            }
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.put("/{session_id}/list/items/order", response_model=List[SessionListItemResponse])
async def update_items_order(
    session_id: int,
    order_data: SessionListOrderUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить порядок пунктов во временном списке."""
    list_service = SessionListService(db)
    
    session_service = SessionService(db)
    participant = await session_service._get_participant(session_id, current_user.id)
    
    if participant.is_ready:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot edit list after marking ready"
        )
    
    try:
        items = await list_service.update_order(session_id, order_data.items)
        
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
                "type": "list_updated",
                "payload": {"items": items_data}
            }
        )
        
        return items_data
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/{session_id}/ready", response_model=dict)
async def mark_ready(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отметить текущего пользователя как готового."""
    session_service = SessionService(db)
    
    try:
        result = await session_service.mark_ready(session_id, current_user.id)
        session_detail = await session_service.get_session_detail(session_id, current_user.id)
        
        # Рассылаем уведомление
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "user_ready",
                "payload": {
                    "user_id": current_user.id,
                    "username": current_user.username,
                    "participants": session_detail["participants"]
                }
            }
        )
        
        if result.get("countdown_started"):
            await manager.broadcast_to_session(
                session_id,
                {
                    "type": "countdown_started",
                    "payload": {
                        "countdown_ends_at": session_detail["countdown_ends_at"].isoformat() if session_detail["countdown_ends_at"] else None
                    }
                }
            )
        
        if session_detail["status"] == "voting":
            await manager.broadcast_to_session(
                session_id,
                {
                    "type": "session_state_changed",
                    "payload": session_detail
                }
            )
        
        return {
            "success": True,
            "message": "Marked as ready",
            "countdown_started": result.get("countdown_started", False)
        }
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/{session_id}/vote", response_model=VoteResultResponse)
async def submit_vote(
    session_id: int,
    vote_data: VoteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отправить голос."""
    session_service = SessionService(db)
    
    try:
        all_voted, results = await session_service.submit_vote(
            session_id=session_id,
            user_id=current_user.id,
            ranked_item_ids=vote_data.ranked_item_ids,
            spin=vote_data.spin
        )
        
        session_detail = await session_service.get_session_detail(session_id, current_user.id)
        
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "user_voted",
                "payload": {
                    "user_id": current_user.id,
                    "username": current_user.username,
                    "participants": session_detail["participants"]
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
            message="Vote submitted successfully",
            all_voted=all_voted
        )
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )


@router.get("/{session_id}/results", response_model=SessionResultsResponse)
async def get_session_results(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить результаты завершенной сессии."""
    session_service = SessionService(db)
    
    try:
        session_detail = await session_service.get_session_detail(session_id, current_user.id)
        
        if session_detail["status"] != "results":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Session is not completed yet"
            )
        
        return session_detail["results"]
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )


@router.post("/{session_id}/reset", response_model=SessionResponse)
async def reset_for_new_round(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Сбросить сессию для нового раунда (только создатель)."""
    session_service = SessionService(db)
    
    try:
        session = await session_service.reset_for_new_round(session_id, current_user.id)
        
        session_detail = await session_service.get_session_detail(session_id, current_user.id)
        await manager.broadcast_to_session(
            session_id,
            {
                "type": "session_state_changed",
                "payload": session_detail
            }
        )
        
        return session
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/{session_id}/cancel", response_model=dict)
async def cancel_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отменить активную сессию."""
    from app.models.session import Session, SessionStatus
    from sqlalchemy import select
    
    result = await db.execute(
        select(Session).where(Session.id == session_id)
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    if session.created_by != current_user.id:
        from app.models.group import GroupMember, GroupRole
        member_result = await db.execute(
            select(GroupMember).where(
                GroupMember.group_id == session.group_id,
                GroupMember.user_id == current_user.id,
                GroupMember.role == GroupRole.ADMIN
            )
        )
        if not member_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only session creator or group admin can cancel the session"
            )
    
    session.status = SessionStatus.CANCELLED
    await db.commit()
    
    await manager.broadcast_to_session(
        session_id,
        {
            "type": "session_cancelled",
            "payload": {
                "session_id": session_id,
                "cancelled_by": current_user.username
            }
        }
    )
    
    return {"success": True, "message": "Session cancelled"}