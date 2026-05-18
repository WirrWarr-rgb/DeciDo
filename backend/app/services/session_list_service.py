# app/services/session_list_service.py
from typing import Optional, List, Dict, Any
from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.session import Session, SessionList, SessionListItem, SessionStatus
from app.models.list import ItemList, ListItem
from app.models.user import User


class SessionListService:
    """Сервис для управления списками в лобби"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_list_from_data(
        self,
        session_id: int,
        name: str,
        items_data: List[Dict[str, Any]],
        set_active: bool = True
    ) -> SessionList:
        """Создать список в лобби из переданных данных (не из БД)"""
        
        # Сбрасываем is_active у других списков этого лобби
        if set_active:
            await self.db.execute(
                update(SessionList)
                .where(SessionList.session_id == session_id)
                .values(is_active=False)
            )
        
        # Создаём список
        session_list = SessionList(
            session_id=session_id,
            name=name,
            is_active=set_active
        )
        self.db.add(session_list)
        await self.db.flush()
        
        # Создаём пункты из переданных данных
        for item_data in items_data:
            session_item = SessionListItem(
                session_list_id=session_list.id,
                name=item_data["name"],
                description=item_data.get("description"),
                image_url=item_data.get("image_url"),
                order_index=item_data.get("order_index", 0)
            )
            self.db.add(session_item)
        
        await self.db.commit()
        await self.db.refresh(session_list)
        
        return session_list
    
    async def switch_active_list(self, session_id: int, new_list_id: int) -> SessionList:
        """Сменить активный список в лобби"""
        
        # Проверяем, что список принадлежит сессии
        result = await self.db.execute(
            select(SessionList)
            .options(selectinload(SessionList.items))
            .where(
                SessionList.id == new_list_id,
                SessionList.session_id == session_id
            )
        )
        new_list = result.scalar_one_or_none()
        
        if not new_list:
            raise ValueError("List not found in this session")
        
        # Сбрасываем активность у всех списков
        await self.db.execute(
            update(SessionList)
            .where(SessionList.session_id == session_id)
            .values(is_active=False)
        )
        
        # Делаем выбранный список активным
        new_list.is_active = True
        
        # Обновляем current_list_id в сессии
        session = await self.db.get(Session, session_id)
        session.current_list_id = new_list.id
        
        await self.db.commit()
        await self.db.refresh(new_list)
        
        return new_list
    
    async def get_active_list(self, session_id: int) -> Optional[SessionList]:
        """Получить активный список лобби"""
        result = await self.db.execute(
            select(SessionList)
            .options(selectinload(SessionList.items))
            .where(
                SessionList.session_id == session_id,
                SessionList.is_active == True
            )
        )
        return result.scalar_one_or_none()
    
    async def get_session_lists(self, session_id: int) -> List[SessionList]:
        """Получить все списки лобби"""
        result = await self.db.execute(
            select(SessionList)
            .options(selectinload(SessionList.items))
            .where(SessionList.session_id == session_id)
            .order_by(SessionList.created_at.desc())
        )
        return result.scalars().all()
    
    async def add_item(
        self, 
        session_id: int, 
        user_id: int,
        name: str,
        description: Optional[str] = None,
        image_url: Optional[str] = None
    ) -> SessionListItem:
        """Добавить пункт в активный список"""
        
        active_list = await self.get_active_list(session_id)
        if not active_list:
            raise ValueError("No active list found")
        
        # Проверяем, не заблокирован ли список
        session = await self.db.get(Session, session_id)
        if session.list_locked:
            raise ValueError("List is locked")
        
        # Определяем order_index
        max_order = max([item.order_index for item in active_list.items], default=-1)
        
        item = SessionListItem(
            session_list_id=active_list.id,
            name=name,
            description=description,
            image_url=image_url,
            order_index=max_order + 1,
            created_by=user_id
        )
        self.db.add(item)
        await self.db.commit()
        await self.db.refresh(item)
        
        return item
    
    async def update_item(
        self,
        session_id: int,
        item_id: int,
        name: Optional[str] = None,
        description: Optional[str] = None,
        image_url: Optional[str] = None
    ) -> SessionListItem:
        """Обновить пункт"""
        
        session = await self.db.get(Session, session_id)
        if session.list_locked:
            raise ValueError("List is locked")
        
        result = await self.db.execute(
            select(SessionListItem)
            .join(SessionList)
            .where(
                SessionListItem.id == item_id,
                SessionList.session_id == session_id
            )
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise ValueError("Item not found")
        
        if name is not None:
            item.name = name
        if description is not None:
            item.description = description
        if image_url is not None:
            item.image_url = image_url
        
        await self.db.commit()
        await self.db.refresh(item)
        
        return item
    
    async def delete_item(self, session_id: int, item_id: int) -> None:
        """Удалить пункт"""
        
        session = await self.db.get(Session, session_id)
        if session.list_locked:
            raise ValueError("List is locked")
        
        result = await self.db.execute(
            select(SessionListItem)
            .join(SessionList)
            .where(
                SessionListItem.id == item_id,
                SessionList.session_id == session_id
            )
        )
        item = result.scalar_one_or_none()
        
        if not item:
            raise ValueError("Item not found")
        
        await self.db.delete(item)
        await self.db.commit()
    
    async def update_order(
        self, 
        session_id: int, 
        items_order: List[Dict[str, int]]
    ) -> List[SessionListItem]:
        """Обновить порядок пунктов"""
        
        session = await self.db.get(Session, session_id)
        if session.list_locked:
            raise ValueError("List is locked")
        
        for item_data in items_order:
            await self.db.execute(
                update(SessionListItem)
                .where(SessionListItem.id == item_data["id"])
                .values(order_index=item_data["order_index"])
            )
        
        await self.db.commit()
        
        active_list = await self.get_active_list(session_id)
        return active_list.items if active_list else []
    
    async def get_creator_name(self, item: SessionListItem) -> Optional[str]:
        """Получить имя создателя пункта"""
        if item.created_by:
            result = await self.db.execute(
                select(User).where(User.id == item.created_by)
            )
            user = result.scalar_one_or_none()
            return user.username if user else None
        return None