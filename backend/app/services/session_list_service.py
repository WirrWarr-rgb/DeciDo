# app/services/session_list_service.py
from typing import List, Optional, Dict, Any
from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.session import Session, SessionList, SessionListItem, SessionStatus
from app.models.list import ItemList, ListItem
from app.models.user import User


class SessionListService:
    """Сервис для управления временным списком сессии"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_session_list(
        self, 
        session_id: int, 
        original_list_id: int
    ) -> SessionList:
        """
        Создать временный список для сессии путём копирования оригинального.
        """
        # Получаем оригинальный список с пунктами
        result = await self.db.execute(
            select(ItemList)
            .options(selectinload(ItemList.items))
            .where(ItemList.id == original_list_id)
        )
        original_list = result.scalar_one_or_none()
        
        if not original_list:
            raise ValueError(f"Original list {original_list_id} not found")
        
        # Создаём временный список
        session_list = SessionList(
            session_id=session_id,
            original_list_id=original_list_id,
            name=original_list.name
        )
        self.db.add(session_list)
        await self.db.flush()
        
        # Копируем пункты
        for item in original_list.items:
            session_item = SessionListItem(
                session_list_id=session_list.id,
                name=item.name,
                description=item.description,
                image_url=item.image_url,
                order_index=item.order_index,
                created_by=None  # Системное создание
            )
            self.db.add(session_item)
        
        await self.db.commit()
        await self.db.refresh(session_list)
        
        return session_list
    
    async def get_session_list(self, session_id: int) -> Optional[SessionList]:
        """Получить временный список сессии."""
        result = await self.db.execute(
            select(SessionList)
            .options(selectinload(SessionList.items))
            .where(SessionList.session_id == session_id)
        )
        return result.scalar_one_or_none()
    
    async def add_item(
        self, 
        session_id: int, 
        user_id: int,
        name: str, 
        description: Optional[str] = None,
        image_url: Optional[str] = None
    ) -> SessionListItem:
        """Добавить пункт во временный список."""
        session_list = await self.get_session_list(session_id)
        if not session_list:
            raise ValueError("Session list not found")
        
        # Проверяем, что сессия в статусе редактирования или отсчёта
        session = await self._get_session(session_id)
        if session.status not in [SessionStatus.LOBBY_EDITING, SessionStatus.LOBBY_COUNTDOWN]:
            raise ValueError("Cannot edit list in current session status")
        
        # Определяем order_index (в конец списка)
        max_order = max([item.order_index for item in session_list.items], default=-1)
        
        new_item = SessionListItem(
            session_list_id=session_list.id,
            name=name,
            description=description,
            image_url=image_url,
            order_index=max_order + 1,
            created_by=user_id
        )
        self.db.add(new_item)
        await self.db.commit()
        await self.db.refresh(new_item)
        
        return new_item
    
    async def update_item(
        self,
        session_id: int,
        item_id: int,
        user_id: int,
        name: Optional[str] = None,
        description: Optional[str] = None,
        image_url: Optional[str] = None
    ) -> SessionListItem:
        """Обновить пункт временного списка."""
        session = await self._get_session(session_id)
        if session.status not in [SessionStatus.LOBBY_EDITING, SessionStatus.LOBBY_COUNTDOWN]:
            raise ValueError("Cannot edit list in current session status")
        
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
        """Удалить пункт из временного списка."""
        session = await self._get_session(session_id)
        if session.status not in [SessionStatus.LOBBY_EDITING, SessionStatus.LOBBY_COUNTDOWN]:
            raise ValueError("Cannot edit list in current session status")
        
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
        """Обновить порядок пунктов."""
        session = await self._get_session(session_id)
        if session.status not in [SessionStatus.LOBBY_EDITING, SessionStatus.LOBBY_COUNTDOWN]:
            raise ValueError("Cannot edit list in current session status")
        
        session_list = await self.get_session_list(session_id)
        if not session_list:
            raise ValueError("Session list not found")
        
        # Создаём словарь существующих ID для проверки
        existing_ids = {item.id for item in session_list.items}
        
        for item_data in items_order:
            item_id = item_data.get("id")
            order_index = item_data.get("order_index")
            
            if item_id not in existing_ids:
                continue
            
            await self.db.execute(
                update(SessionListItem)
                .where(SessionListItem.id == item_id)
                .values(order_index=order_index)
            )
        
        await self.db.commit()
        
        # Возвращаем обновлённый список
        await self.db.refresh(session_list)
        return session_list.items
    
    async def _get_session(self, session_id: int) -> Session:
        """Получить сессию по ID."""
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError(f"Session {session_id} not found")
        return session
    
    async def get_item_creator_name(self, item: SessionListItem) -> Optional[str]:
        """Получить имя создателя пункта."""
        if item.created_by:
            result = await self.db.execute(
                select(User).where(User.id == item.created_by)
            )
            user = result.scalar_one_or_none()
            return user.username if user else None
        return None