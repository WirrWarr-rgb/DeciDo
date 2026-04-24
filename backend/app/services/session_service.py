# app/services/session_service.py
import random
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any, Tuple

from sqlalchemy import select, and_, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.session import (
    Session, SessionParticipant, SessionResult,
    SessionStatus, SessionMode, SessionList, SessionListItem,
    ParticipantStatus
)
from app.models.user import User
from app.services.session_list_service import SessionListService


class SessionService:
    """Сервис для управления лобби"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.list_service = SessionListService(db)
    
    # ============= Создание лобби =============
    
    async def create_lobby(
        self,
        owner_id: int,
        friend_ids: List[int],
        list_id: int,
        mode: SessionMode = SessionMode.RANKING,
        voting_duration: int = 120
    ) -> Session:
        """Создать новое лобби"""
        
        # Создаём сессию
        session = Session(
            owner_id=owner_id,
            mode=mode,
            status=SessionStatus.WAITING,
            voting_duration=voting_duration
        )
        self.db.add(session)
        await self.db.flush()
        
        # Создаём список из оригинального
        session_list = await self.list_service.create_list_from_original(
            session.id, list_id, set_active=True
        )
        session.current_list_id = session_list.id
        
        # Добавляем владельца как участника
        owner_participant = SessionParticipant(
            session_id=session.id,
            user_id=owner_id,
            status=ParticipantStatus.ACCEPTED,
            is_ready=False,
            joined_at=datetime.now(timezone.utc)
        )
        self.db.add(owner_participant)
        
        # Добавляем приглашённых друзей
        for friend_id in friend_ids:
            participant = SessionParticipant(
                session_id=session.id,
                user_id=friend_id,
                status=ParticipantStatus.INVITED,
                invited_by=owner_id
            )
            self.db.add(participant)
        
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    # ============= Управление участниками =============
    
    async def accept_invite(self, session_id: int, user_id: int) -> SessionParticipant:
        """Принять приглашение в лобби"""
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.status != ParticipantStatus.INVITED:
            raise ValueError("User is not invited")
        
        participant.status = ParticipantStatus.ACCEPTED
        participant.joined_at = datetime.now(timezone.utc)
        
        await self.db.commit()
        await self.db.refresh(participant)
        
        # Проверяем, все ли приглашённые приняли
        await self._check_all_accepted(session_id)
        
        return participant
    
    async def decline_invite(self, session_id: int, user_id: int) -> None:
        """Отклонить приглашение"""
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.status != ParticipantStatus.INVITED:
            raise ValueError("User is not invited")
        
        participant.status = ParticipantStatus.DECLINED
        await self.db.commit()
    
    async def invite_friends(
        self, 
        session_id: int, 
        inviter_id: int, 
        friend_ids: List[int]
    ) -> List[SessionParticipant]:
        """Пригласить ещё друзей (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != inviter_id:
            raise ValueError("Only owner can invite")
        
        new_participants = []
        for friend_id in friend_ids:
            # Проверяем, не участвует ли уже
            existing = await self.db.execute(
                select(SessionParticipant).where(
                    SessionParticipant.session_id == session_id,
                    SessionParticipant.user_id == friend_id
                )
            )
            if existing.scalar_one_or_none():
                continue
            
            participant = SessionParticipant(
                session_id=session_id,
                user_id=friend_id,
                status=ParticipantStatus.INVITED,
                invited_by=inviter_id
            )
            self.db.add(participant)
            new_participants.append(participant)
        
        await self.db.commit()
        return new_participants
    
    async def leave_lobby(self, session_id: int, user_id: int) -> Dict[str, Any]:
        """Выйти из лобби"""
        
        session = await self._get_session(session_id)
        participant = await self._get_participant(session_id, user_id)
        
        is_owner = (session.owner_id == user_id)
        should_close = False
        
        if is_owner:
            # Владелец выходит = закрытие лобби
            should_close = True
        elif session.status == SessionStatus.RESULTS:
            # Обычный участник после результатов просто выходит
            participant.status = ParticipantStatus.LEFT
            participant.left_at = datetime.now(timezone.utc)
        else:
            # Во время активной сессии тоже можно выйти
            participant.status = ParticipantStatus.LEFT
            participant.left_at = datetime.now(timezone.utc)
        
        if should_close:
            await self.close_lobby(session_id, user_id)
        
        await self.db.commit()
        
        return {
            "left": True,
            "lobby_closed": should_close
        }
    
    async def close_lobby(self, session_id: int, user_id: int) -> None:
        """Закрыть лобби (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can close lobby")
        
        session.status = SessionStatus.CLOSED
        session.closed_at = datetime.now(timezone.utc)
        session.closed_by = user_id
        
        await self.db.commit()
    
    # ============= Управление списком =============
    
    async def change_list(self, session_id: int, user_id: int, new_list_id: int) -> SessionList:
        """Сменить список (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can change list")
        
        if session.status not in [SessionStatus.WAITING, SessionStatus.EDITING]:
            raise ValueError("Cannot change list in current status")
        
        # Создаём новый список из оригинального
        new_list = await self.list_service.create_list_from_original(
            session_id, new_list_id, set_active=False
        )
        
        # Переключаемся на него
        await self.list_service.switch_active_list(session_id, new_list.id)
        
        return new_list
    
    async def lock_list(self, session_id: int, user_id: int) -> Session:
        """Заблокировать список (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can lock list")
        
        session.list_locked = True
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    async def unlock_list(self, session_id: int, user_id: int) -> Session:
        """Разблокировать список (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can unlock list")
        
        session.list_locked = False
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    # ============= Готовность и старт =============
    
    async def mark_ready(self, session_id: int, user_id: int) -> SessionParticipant:
        """Отметить готовность"""
        
        session = await self._get_session(session_id)
        
        if session.status != SessionStatus.EDITING:
            raise ValueError("Lobby is not in editing state")
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.status != ParticipantStatus.ACCEPTED:
            raise ValueError("User is not an active participant")
        
        participant.is_ready = True
        participant.ready_at = datetime.now(timezone.utc)
        
        await self.db.commit()
        await self.db.refresh(participant)
        
        # Проверяем, все ли готовы
        await self._check_all_ready(session_id)
        
        return participant
    
    async def force_start(self, session_id: int, user_id: int) -> Session:
        """Принудительно начать голосование (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can force start")
        
        if session.status not in [SessionStatus.EDITING, SessionStatus.READY]:
            raise ValueError("Cannot start in current status")
        
        return await self._start_voting(session_id)
    
    # ============= Голосование =============
    
    async def submit_vote(
        self,
        session_id: int,
        user_id: int,
        ranked_item_ids: Optional[List[int]] = None,
        spin: bool = False
    ) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Отправить голос"""
        
        session = await self._get_session(session_id)
        
        if session.status != SessionStatus.VOTING:
            raise ValueError("Voting is not active")
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.has_voted:
            raise ValueError("Already voted")
        
        active_list = await self.list_service.get_active_list(session_id)
        if not active_list:
            raise ValueError("No active list")
        
        if session.mode == SessionMode.RANKING:
            if not ranked_item_ids:
                raise ValueError("ranked_item_ids required")
            
            valid_ids = {item.id for item in active_list.items}
            if set(ranked_item_ids) != valid_ids:
                raise ValueError("Must include all items exactly once")
            
            participant.vote_data = {"ranked_ids": ranked_item_ids}
        else:
            if not spin:
                raise ValueError("spin required for random mode")
            participant.has_spun = True
        
        participant.has_voted = True
        participant.voted_at = datetime.now(timezone.utc)
        
        await self.db.commit()
        
        # Проверяем, все ли проголосовали
        all_voted = await self._check_all_voted(session_id)
        results = None
        
        if all_voted:
            results = await self._calculate_results(session_id)
        
        return all_voted, results
    
    async def back_to_lobby(self, session_id: int, user_id: int) -> Session:
        """Вернуться в лобби после результатов (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can go back to lobby")
        
        if session.status != SessionStatus.RESULTS:
            raise ValueError("Session is not in results state")
        
        # Сбрасываем статус
        session.status = SessionStatus.EDITING
        session.started_at = None
        session.voting_ends_at = None
        session.results_json = None
        
        # Сбрасываем голоса и готовность
        await self.db.execute(
            update(SessionParticipant)
            .where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.ACCEPTED
            )
            .values(
                is_ready=False,
                has_voted=False,
                has_spun=False,
                vote_data=None,
                ready_at=None,
                voted_at=None
            )
        )
        
        # Удаляем старые результаты
        await self.db.execute(
            delete(SessionResult).where(SessionResult.session_id == session_id)
        )
        
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    # ============= Подсчёт результатов =============
    
    async def _calculate_results(self, session_id: int) -> Dict[str, Any]:
        """Подсчитать результаты голосования"""
        
        session = await self._get_session(session_id, load_participants=True)
        active_list = await self.list_service.get_active_list(session_id)
        
        if not active_list:
            raise ValueError("No active list")
        
        if session.mode == SessionMode.RANDOM:
            results = await self._calculate_random_results(session, active_list)
        else:
            results = await self._calculate_ranking_results(session, active_list)
        
        session.results_json = results
        session.status = SessionStatus.RESULTS
        session.completed_at = datetime.now(timezone.utc)
        
        # Сохраняем в таблицу
        for item_result in results["results"]:
            session_result = SessionResult(
                session_id=session_id,
                session_list_item_id=item_result["item_id"],
                total_score=item_result["total_score"],
                place=item_result["place"]
            )
            self.db.add(session_result)
        
        await self.db.commit()
        
        return results
    
    async def _calculate_ranking_results(
        self, 
        session: Session, 
        active_list: SessionList
    ) -> Dict[str, Any]:
        """Подсчёт для ранжирования"""
        
        items = active_list.items
        n_items = len(items)
        
        if n_items == 0:
            raise ValueError("List is empty")
        
        scores = {item.id: 0 for item in items}
        voted_count = 0
        
        for p in session.participants:
            if p.status != ParticipantStatus.ACCEPTED:
                continue
            if not p.has_voted or not p.vote_data:
                continue
            
            voted_count += 1
            ranked_ids = p.vote_data.get("ranked_ids", [])
            
            for position, item_id in enumerate(ranked_ids):
                points = n_items - position
                scores[item_id] = scores.get(item_id, 0) + points
        
        sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        
        results = []
        for place, (item_id, score) in enumerate(sorted_scores, 1):
            item = next((i for i in items if i.id == item_id), None)
            results.append({
                "item_id": item_id,
                "item_name": item.name if item else "Unknown",
                "total_score": score,
                "place": place
            })
        
        return {
            "session_id": session.id,
            "winner": results[0] if results else None,
            "results": results,
            "participants_count": len([p for p in session.participants if p.status == ParticipantStatus.ACCEPTED]),
            "voted_count": voted_count
        }
    
    async def _calculate_random_results(
        self, 
        session: Session, 
        active_list: SessionList
    ) -> Dict[str, Any]:
        """Подсчёт для колеса"""
        
        items = active_list.items
        
        if not items:
            raise ValueError("List is empty")
        
        winner = random.choice(items)
        
        results = []
        for item in items:
            results.append({
                "item_id": item.id,
                "item_name": item.name,
                "total_score": 1 if item.id == winner.id else 0,
                "place": 1 if item.id == winner.id else 2
            })
        
        results.sort(key=lambda x: x["place"])
        
        accepted = [p for p in session.participants if p.status == ParticipantStatus.ACCEPTED]
        
        return {
            "session_id": session.id,
            "winner": {
                "item_id": winner.id,
                "item_name": winner.name,
                "total_score": 1,
                "place": 1
            },
            "results": results,
            "participants_count": len(accepted),
            "voted_count": len([p for p in accepted if p.has_voted or p.has_spun])
        }
    
    # ============= Вспомогательные методы =============
    
    async def _check_all_accepted(self, session_id: int) -> None:
        """Проверить, все ли приглашённые приняли"""
        
        result = await self.db.execute(
            select(SessionParticipant).where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.INVITED
            )
        )
        pending = result.scalars().all()
        
        if not pending:
            session = await self._get_session(session_id)
            if session.status == SessionStatus.WAITING:
                session.status = SessionStatus.EDITING
                await self.db.commit()
    
    async def _check_all_ready(self, session_id: int) -> None:
        """Проверить, все ли готовы"""
        
        result = await self.db.execute(
            select(SessionParticipant).where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.ACCEPTED,
                SessionParticipant.is_ready == False
            )
        )
        not_ready = result.scalars().all()
        
        if not not_ready:
            await self._start_voting(session_id)
    
    async def _check_all_voted(self, session_id: int) -> bool:
        """Проверить, все ли проголосовали"""
        
        result = await self.db.execute(
            select(SessionParticipant).where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.ACCEPTED,
                SessionParticipant.has_voted == False
            )
        )
        not_voted = result.scalars().all()
        
        return len(not_voted) == 0
    
    async def _start_voting(self, session_id: int) -> Session:
        """Начать голосование"""
        
        session = await self._get_session(session_id)
        now = datetime.now(timezone.utc)
        
        session.status = SessionStatus.VOTING
        session.started_at = now
        session.voting_ends_at = now + timedelta(seconds=session.voting_duration)
        
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    async def _get_session(
        self, 
        session_id: int, 
        load_participants: bool = False
    ) -> Session:
        """Получить сессию"""
        
        query = select(Session).where(Session.id == session_id)
        
        if load_participants:
            query = query.options(selectinload(Session.participants))
        
        result = await self.db.execute(query)
        session = result.scalar_one_or_none()
        
        if not session:
            raise ValueError("Session not found")
        
        return session
    
    async def _get_participant(self, session_id: int, user_id: int) -> SessionParticipant:
        """Получить участника"""
        
        result = await self.db.execute(
            select(SessionParticipant).where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.user_id == user_id
            )
        )
        participant = result.scalar_one_or_none()
        
        if not participant:
            raise ValueError("User is not a participant")
        
        return participant
    
    # ============= Получение информации =============
    
    async def get_lobby(self, session_id: int, user_id: int) -> Dict[str, Any]:
        """Получить полную информацию о лобби"""
        
        session = await self._get_session(session_id, load_participants=True)
        active_list = await self.list_service.get_active_list(session_id)
        
        # Проверяем, есть ли пользователь в участниках
        participant = next(
            (p for p in session.participants if p.user_id == user_id),
            None
        )
        
        if not participant:
            raise ValueError("User is not a participant")
        
        is_owner = (session.owner_id == user_id)
        
        # Формируем участников
        participants = []
        for p in session.participants:
            user = await self.db.get(User, p.user_id)
            participants.append({
                "user_id": p.user_id,
                "username": user.username if user else "Unknown",
                "status": p.status.value,
                "is_ready": p.is_ready,
                "has_voted": p.has_voted,
                "is_owner": (p.user_id == session.owner_id),
                "invited_at": p.invited_at,
                "joined_at": p.joined_at
            })
        
        # Формируем список
        list_data = None
        if active_list:
            items = []
            for item in active_list.items:
                creator_name = await self.list_service.get_creator_name(item)
                items.append({
                    "id": item.id,
                    "name": item.name,
                    "description": item.description,
                    "image_url": item.image_url,
                    "order_index": item.order_index,
                    "created_by": item.created_by,
                    "creator_name": creator_name
                })
            
            list_data = {
                "id": active_list.id,
                "name": active_list.name,
                "is_active": active_list.is_active,
                "items": items,
                "created_at": active_list.created_at
            }
        
        # Получаем имя владельца
        owner = await self.db.get(User, session.owner_id)
        
        # Определяем права
        can_edit_list = (
            not session.list_locked and
            session.status in [SessionStatus.WAITING, SessionStatus.EDITING]
        )
        can_start = (
            is_owner and
            session.status == SessionStatus.EDITING
        )
        can_invite = (
            is_owner and
            session.status in [SessionStatus.WAITING, SessionStatus.EDITING]
        )
        can_lock_list = (
            is_owner and
            session.status in [SessionStatus.WAITING, SessionStatus.EDITING]
        )
        
        return {
            "id": session.id,
            "owner_id": session.owner_id,
            "owner_name": owner.username if owner else "Unknown",
            "status": session.status.value,
            "mode": session.mode.value,
            "list_locked": session.list_locked,
            "current_list": list_data,
            "participants": participants,
            "voting_duration": session.voting_duration,
            "created_at": session.created_at,
            "voting_ends_at": session.voting_ends_at,
            "results": session.results_json,
            "is_owner": is_owner,
            "can_edit_list": can_edit_list,
            "can_start": can_start,
            "can_invite": can_invite,
            "can_lock_list": can_lock_list
        }
    
    async def get_my_lobbies(self, user_id: int) -> Dict[str, List]:
        """Получить все лобби пользователя"""
        
        # Активные лобби (участник)
        active_result = await self.db.execute(
            select(Session)
            .join(SessionParticipant)
            .where(
                SessionParticipant.user_id == user_id,
                SessionParticipant.status == ParticipantStatus.ACCEPTED,
                Session.status.in_([
                    SessionStatus.WAITING,
                    SessionStatus.EDITING,
                    SessionStatus.READY,
                    SessionStatus.VOTING,
                    SessionStatus.RESULTS
                ])
            )
            .order_by(Session.created_at.desc())
        )
        active = active_result.scalars().all()
        
        # Приглашения
        invitations_result = await self.db.execute(
            select(Session)
            .join(SessionParticipant)
            .where(
                SessionParticipant.user_id == user_id,
                SessionParticipant.status == ParticipantStatus.INVITED,
                Session.status != SessionStatus.CLOSED
            )
            .order_by(Session.created_at.desc())
        )
        invitations = invitations_result.scalars().all()
        
        # История (закрытые или покинутые)
        history_result = await self.db.execute(
            select(Session)
            .join(SessionParticipant)
            .where(
                SessionParticipant.user_id == user_id,
                Session.status.in_([SessionStatus.CLOSED])
            )
            .order_by(Session.closed_at.desc())
            .limit(50)
        )
        history = history_result.scalars().all()
        
        return {
            "active": [await self.get_lobby(s.id, user_id) for s in active],
            "invitations": [await self.get_lobby(s.id, user_id) for s in invitations],
            "history": [await self.get_lobby(s.id, user_id) for s in history]
        }