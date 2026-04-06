from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from typing import List
from app.core.database import get_db
from app.models.user import User
from app.models.friend import Friend, FriendStatus
from app.schemas.friend import (
    FriendRequestCreate, FriendRequestResponse, 
    FriendResponse, FriendRequestAction
)
from app.api.v1.endpoints.auth import get_current_user

router = APIRouter(prefix="/friends", tags=["friends"])

@router.post("/requests", response_model=FriendRequestResponse, status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    request_data: FriendRequestCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отправить заявку в друзья."""
    # Проверяем, что пользователь не отправляет заявку сам себе
    if request_data.friend_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot send friend request to yourself"
        )
    
    # Проверяем, существует ли пользователь
    result = await db.execute(
        select(User).where(User.id == request_data.friend_id)
    )
    friend = result.scalar_one_or_none()
    if not friend:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Проверяем, нет ли уже заявки
    existing_request = await db.execute(
        select(Friend).where(
            or_(
                and_(Friend.user_id == current_user.id, Friend.friend_id == request_data.friend_id),
                and_(Friend.user_id == request_data.friend_id, Friend.friend_id == current_user.id)
            )
        )
    )
    existing = existing_request.scalar_one_or_none()
    if existing:
        if existing.status == FriendStatus.PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Friend request already pending"
            )
        elif existing.status == FriendStatus.ACCEPTED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You are already friends"
            )
    
    # Создаем заявку
    friend_request = Friend(
        user_id=current_user.id,
        friend_id=request_data.friend_id,
        status=FriendStatus.PENDING
    )
    db.add(friend_request)
    await db.commit()
    await db.refresh(friend_request)
    return friend_request

@router.get("/requests/incoming", response_model=List[FriendRequestResponse])
async def get_incoming_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить входящие заявки в друзья."""
    result = await db.execute(
        select(Friend)
        .where(Friend.friend_id == current_user.id)
        .where(Friend.status == FriendStatus.PENDING)
        .order_by(Friend.created_at.desc())
    )
    requests = result.scalars().all()
    return requests

@router.get("/requests/outgoing", response_model=List[FriendRequestResponse])
async def get_outgoing_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить исходящие заявки в друзья."""
    result = await db.execute(
        select(Friend)
        .where(Friend.user_id == current_user.id)
        .where(Friend.status == FriendStatus.PENDING)
        .order_by(Friend.created_at.desc())
    )
    requests = result.scalars().all()
    return requests

@router.put("/requests/{request_id}/accept", response_model=FriendRequestResponse)
async def accept_friend_request(
    request_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Принять заявку в друзья."""
    # Находим заявку
    result = await db.execute(
        select(Friend).where(Friend.id == request_id)
    )
    request = result.scalar_one_or_none()
    
    if not request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend request not found"
        )
    
    # Проверяем, что заявка адресована текущему пользователю
    if request.friend_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to accept this request"
        )
    
    # Проверяем, что заявка в статусе pending
    if request.status != FriendStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Friend request is not pending"
        )
    
    # Принимаем заявку
    request.status = FriendStatus.ACCEPTED
    await db.commit()
    await db.refresh(request)
    return request

@router.put("/requests/{request_id}/reject", response_model=FriendRequestResponse)
async def reject_friend_request(
    request_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отклонить заявку в друзья."""
    # Находим заявку
    result = await db.execute(
        select(Friend).where(Friend.id == request_id)
    )
    request = result.scalar_one_or_none()
    
    if not request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend request not found"
        )
    
    # Проверяем, что заявка адресована текущему пользователю
    if request.friend_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to reject this request"
        )
    
    # Проверяем, что заявка в статусе pending
    if request.status != FriendStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Friend request is not pending"
        )
    
    # Отклоняем заявку
    request.status = FriendStatus.REJECTED
    await db.commit()
    await db.refresh(request)
    return request

@router.get("/", response_model=List[FriendResponse])
async def get_friends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить список друзей."""
    # Находим все принятые заявки, где пользователь - инициатор или получатель
    result = await db.execute(
        select(Friend)
        .where(
            or_(
                and_(Friend.user_id == current_user.id, Friend.status == FriendStatus.ACCEPTED),
                and_(Friend.friend_id == current_user.id, Friend.status == FriendStatus.ACCEPTED)
            )
        )
    )
    friendships = result.scalars().all()
    
    # Получаем данные друзей
    friends = []
    for f in friendships:
        friend_id = f.friend_id if f.user_id == current_user.id else f.user_id
        result = await db.execute(select(User).where(User.id == friend_id))
        friend = result.scalar_one()
        friends.append(friend)
    
    return friends

@router.delete("/{friend_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_friend(
    friend_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить из друзей."""
    # Находим дружбу
    result = await db.execute(
        select(Friend)
        .where(
            or_(
                and_(Friend.user_id == current_user.id, Friend.friend_id == friend_id),
                and_(Friend.friend_id == current_user.id, Friend.user_id == friend_id)
            )
        )
        .where(Friend.status == FriendStatus.ACCEPTED)
    )
    friendship = result.scalar_one_or_none()
    
    if not friendship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friendship not found"
        )
    
    await db.delete(friendship)
    await db.commit()