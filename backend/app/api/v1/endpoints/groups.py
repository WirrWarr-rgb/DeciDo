from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from typing import List
from app.core.database import get_db
from app.models.user import User
from app.models.group import Group, GroupMember, GroupRole
from app.models.friend import Friend, FriendStatus
from app.schemas.group import (
    GroupCreate, GroupUpdate, GroupResponse, 
    GroupDetailResponse, GroupMemberResponse, GroupInviteCreate
)
from app.api.v1.endpoints.auth import get_current_user

router = APIRouter(prefix="/groups", tags=["groups"])

@router.post("/", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
async def create_group(
    group_data: GroupCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Создать новую группу."""
    new_group = Group(
        name=group_data.name,
        description=group_data.description,
        owner_id=current_user.id
    )
    db.add(new_group)
    await db.flush()
    
    # Добавляем создателя как админа
    group_member = GroupMember(
        group_id=new_group.id,
        user_id=current_user.id,
        role=GroupRole.ADMIN
    )
    db.add(group_member)
    
    await db.commit()
    await db.refresh(new_group)
    return new_group

@router.get("/", response_model=List[GroupResponse])
async def get_my_groups(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить все группы, где состоит пользователь."""
    result = await db.execute(
        select(Group)
        .join(GroupMember)
        .where(GroupMember.user_id == current_user.id)
        .order_by(Group.created_at.desc())
    )
    groups = result.scalars().all()
    return groups

@router.get("/{group_id}", response_model=GroupDetailResponse)
async def get_group_detail(
    group_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить детальную информацию о группе."""
    # Проверяем, что пользователь состоит в группе
    membership = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == current_user.id))
    )
    if not membership.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group"
        )
    
    # Получаем группу
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found"
        )
    
    # Получаем участников
    members_result = await db.execute(
        select(GroupMember, User)
        .join(User, GroupMember.user_id == User.id)
        .where(GroupMember.group_id == group_id)
    )
    
    members = []
    for gm, user in members_result:
        members.append(GroupMemberResponse(
            id=gm.id,
            user_id=user.id,
            username=user.username,
            email=user.email,
            role=gm.role,
            joined_at=gm.joined_at
        ))
    
    return GroupDetailResponse(
        id=group.id,
        name=group.name,
        description=group.description,
        owner_id=group.owner_id,
        created_at=group.created_at,
        updated_at=group.updated_at,
        members=members
    )

@router.put("/{group_id}", response_model=GroupResponse)
async def update_group(
    group_id: int,
    group_data: GroupUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить группу (только для админа)."""
    # Проверяем права
    membership = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == current_user.id))
    )
    member = membership.scalar_one_or_none()
    
    if not member or member.role != GroupRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group admin can update the group"
        )
    
    # Получаем группу
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found"
        )
    
    if group_data.name is not None:
        group.name = group_data.name
    if group_data.description is not None:
        group.description = group_data.description
    
    await db.commit()
    await db.refresh(group)
    return group

@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_group(
    group_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить группу (только для админа)."""
    # Проверяем права
    membership = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == current_user.id))
    )
    member = membership.scalar_one_or_none()
    
    if not member or member.role != GroupRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group admin can delete the group"
        )
    
    # Получаем группу
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found"
        )
    
    await db.delete(group)
    await db.commit()

@router.post("/{group_id}/invite", status_code=status.HTTP_200_OK)
async def invite_to_group(
    group_id: int,
    invite_data: GroupInviteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Пригласить пользователя в группу (только друзей)."""
    # Проверяем, что пользователь - админ группы
    membership = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == current_user.id))
    )
    member = membership.scalar_one_or_none()
    
    if not member or member.role != GroupRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group admin can invite users"
        )
    
    # Проверяем, что приглашаемый пользователь - друг
    friendship = await db.execute(
        select(Friend)
        .where(
            and_(
                Friend.status == FriendStatus.ACCEPTED,
                or_(
                    and_(Friend.user_id == current_user.id, Friend.friend_id == invite_data.user_id),
                    and_(Friend.friend_id == current_user.id, Friend.user_id == invite_data.user_id)
                )
            )
        )
    )
    if not friendship.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Can only invite friends to the group"
        )
    
    # Проверяем, не состоит ли уже пользователь в группе
    existing = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == invite_data.user_id))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member of this group"
        )
    
    # Добавляем пользователя в группу как участника
    new_member = GroupMember(
        group_id=group_id,
        user_id=invite_data.user_id,
        role=GroupRole.MEMBER
    )
    db.add(new_member)
    await db.commit()
    
    return {"message": "User invited successfully"}

@router.delete("/{group_id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_group(
    group_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить пользователя из группы (только для админа)."""
    # Проверяем права
    membership = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == current_user.id))
    )
    admin_member = membership.scalar_one_or_none()
    
    if not admin_member or admin_member.role != GroupRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group admin can remove members"
        )
    
    # Нельзя удалить самого себя
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Admin cannot remove themselves. Use leave endpoint instead."
        )
    
    # Находим участника
    result = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == user_id))
    )
    member = result.scalar_one_or_none()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User is not a member of this group"
        )
    
    await db.delete(member)
    await db.commit()

@router.post("/{group_id}/leave", status_code=status.HTTP_200_OK)
async def leave_group(
    group_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Выйти из группы."""
    # Находим участника
    result = await db.execute(
        select(GroupMember)
        .where(and_(GroupMember.group_id == group_id, GroupMember.user_id == current_user.id))
    )
    member = result.scalar_one_or_none()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of this group"
        )
    
    # Проверяем, не является ли пользователь единственным админом
    if member.role == GroupRole.ADMIN:
        # Проверяем, есть ли другие админы
        admins = await db.execute(
            select(GroupMember)
            .where(and_(GroupMember.group_id == group_id, GroupMember.role == GroupRole.ADMIN))
        )
        admin_count = len(admins.scalars().all())
        
        if admin_count == 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot leave group as the only admin. Transfer admin role or delete the group."
            )
    
    await db.delete(member)
    await db.commit()
    
    return {"message": "Left group successfully"}