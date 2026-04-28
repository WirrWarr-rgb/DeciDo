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
        list_name: str,             # <-- название списка
        list_items: List[Dict],     # <-- пункты списка
        mode: SessionMode = SessionMode.RANKING,
        voting_duration: int = 120
    ) -> Session:
        """Создать новое лобби"""
        
        session = Session(
            owner_id=owner_id,
            mode=mode,
            status=SessionStatus.WAITING,
            voting_duration=voting_duration
        )
        self.db.add(session)
        await self.db.flush()
        
        # Создаём список из переданных данных (не из БД!)
        session_list = await self.list_service.create_list_from_data(
            session.id, list_name, list_items, set_active=True
        )
        session.current_list_id = session_list.id
        
        # Добавляем владельца
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
        
        await self._check_all_accepted(session_id)
        
        return participant
    
    async def decline_invite(self, session_id: int, user_id: int) -> None:
        """Отклонить приглашение"""
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.status != ParticipantStatus.INVITED:
            raise ValueError("User is not invited")
        
        participant.status = ParticipantStatus.DECLINED
        await self.db.commit()
    
    async def kick_participant(self, session_id: int, kicker_id: int, target_user_id: int) -> None:
        """Изгнать участника (только хост)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != kicker_id:
            raise ValueError("Only owner can kick participants")
        
        if target_user_id == kicker_id:
            raise ValueError("Cannot kick yourself")
        
        participant = await self._get_participant(session_id, target_user_id)
        participant.status = ParticipantStatus.KICKED
        participant.left_at = datetime.now(timezone.utc)
        
        await self.db.commit()
        
        # Пересчитываем таймер
        await self._recalculate_countdown(session_id)
    
    async def leave_lobby(self, session_id: int, user_id: int) -> Dict[str, Any]:
        """Выйти из лобби"""
        
        session = await self._get_session(session_id)
        participant = await self._get_participant(session_id, user_id)
        
        is_owner = (session.owner_id == user_id)
        should_close = False
        
        if is_owner:
            should_close = True
            await self.close_lobby(session_id, user_id)
        else:
            participant.status = ParticipantStatus.LEFT
            participant.left_at = datetime.now(timezone.utc)
            await self.db.commit()
            await self._recalculate_countdown(session_id)
        
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
        
        # Всех участников помечаем как LEFT
        await self.db.execute(
            update(SessionParticipant)
            .where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.ACCEPTED
            )
            .values(
                status=ParticipantStatus.LEFT,
                left_at=datetime.now(timezone.utc)
            )
        )
        
        await self.db.commit()
    
    # ============= Готовность и таймер =============
    
    async def mark_ready(self, session_id: int, user_id: int) -> SessionParticipant:
        """Отметить готовность"""
        
        session = await self._get_session(session_id)
        
        if session.status not in [SessionStatus.WAITING, SessionStatus.EDITING, SessionStatus.READY]:
            raise ValueError("Cannot mark ready in current status")
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.status != ParticipantStatus.ACCEPTED:
            raise ValueError("User is not an active participant")
        
        participant.is_ready = True
        participant.ready_at = datetime.now(timezone.utc)
        
        await self.db.commit()
        await self.db.refresh(participant)
        
        await self._recalculate_countdown(session_id)
        
        return participant
    
    async def mark_unready(self, session_id: int, user_id: int) -> SessionParticipant:
        """Отменить готовность"""
        
        session = await self._get_session(session_id)
        
        if session.status not in [SessionStatus.EDITING, SessionStatus.READY]:
            raise ValueError("Cannot unready in current status")
        
        participant = await self._get_participant(session_id, user_id)
        
        if participant.status != ParticipantStatus.ACCEPTED:
            raise ValueError("User is not an active participant")
        
        participant.is_ready = False
        participant.ready_at = None
        
        await self.db.commit()
        await self.db.refresh(participant)
        
        await self._recalculate_countdown(session_id)
        
        return participant
    
    async def _recalculate_countdown(self, session_id: int) -> None:
        """
        Пересчитать таймер в зависимости от количества готовых.
        Таймер может только уменьшаться, но не увеличиваться.
        """
        session = await self._get_session(session_id)
        
        # Считаем принятых участников
        result = await self.db.execute(
            select(SessionParticipant).where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.ACCEPTED
            )
        )
        accepted = result.scalars().all()
        total = len(accepted)
        
        if total == 0:
            return
        
        ready_count = len([p for p in accepted if p.is_ready])
        now = datetime.now(timezone.utc)
        
        if ready_count == 0:
            # Сбрасываем таймер
            session.countdown_ends_at = None
            if session.status == SessionStatus.READY:
                session.status = SessionStatus.EDITING
            await self.db.commit()
            return
        
        # Определяем длительность таймера
        if ready_count == total:
            target_seconds = 5
        elif total - ready_count == 1:
            target_seconds = 20
        elif ready_count > total / 2:
            target_seconds = 60
        else:
            target_seconds = 180
        
        new_ends_at = now + timedelta(seconds=target_seconds)
        
        # Таймер может только уменьшаться!
        if session.countdown_ends_at is None or new_ends_at < session.countdown_ends_at:
            session.countdown_ends_at = new_ends_at
            session.status = SessionStatus.READY
        
        await self.db.commit()
    
    async def force_start(self, session_id: int, user_id: int) -> Session:
        """Принудительно начать голосование (только владелец)"""
        
        session = await self._get_session(session_id)
        
        if session.owner_id != user_id:
            raise ValueError("Only owner can force start")
        
        if session.status not in [SessionStatus.EDITING, SessionStatus.READY]:
            raise ValueError("Cannot start in current status")
        
        return await self._start_voting(session_id)
    
    async def check_countdowns_and_transition(self) -> List[int]:
        """Проверить таймеры готовности и перевести в голосование при истечении"""
        
        now = datetime.now(timezone.utc)
        
        result = await self.db.execute(
            select(Session).where(
                and_(
                    Session.status == SessionStatus.READY,
                    Session.countdown_ends_at <= now
                )
            )
        )
        expired_sessions = result.scalars().all()
        
        updated = []
        for session in expired_sessions:
            await self._start_voting(session.id)
            updated.append(session.id)
        
        # Также проверяем таймеры голосования
        voting_expired = await self.db.execute(
            select(Session).where(
                and_(
                    Session.status == SessionStatus.VOTING,
                    Session.voting_ends_at <= now
                )
            )
        )
        
        for session in voting_expired.scalars().all():
            await self._calculate_results(session.id)
            updated.append(session.id)
        
        await self.db.commit()
        return updated
    
    # ============= Голосование и результаты =============
    
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
            
            # Проверяем, что все ID из списка (но разрешаем не все)
            valid_ids = {item.id for item in active_list.items}
            for rid in ranked_item_ids:
                if rid not in valid_ids:
                    raise ValueError(f"Item {rid} not in list")
            
            if len(ranked_item_ids) != len(set(ranked_item_ids)):
                raise ValueError("Duplicate items not allowed")
            
            participant.vote_data = {"ranked_ids": ranked_item_ids}
        else:
            if not spin:
                raise ValueError("spin required for random mode")
            participant.has_spun = True
        
        participant.has_voted = True
        participant.voted_at = datetime.now(timezone.utc)
        
        await self.db.commit()
        
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
        
        session.status = SessionStatus.EDITING
        session.started_at = None
        session.voting_ends_at = None
        session.countdown_ends_at = None
        session.results_json = None
        
        await self.db.execute(
            update(SessionParticipant)
            .where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status.in_([ParticipantStatus.ACCEPTED, ParticipantStatus.LEFT])
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
        
        # Возвращаем LEFT участников обратно (если они вышли после результатов)
        await self.db.execute(
            update(SessionParticipant)
            .where(
                SessionParticipant.session_id == session_id,
                SessionParticipant.status == ParticipantStatus.LEFT
            )
            .values(status=ParticipantStatus.ACCEPTED)
        )
        
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
        session.countdown_ends_at = None
        
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
        """Подсчёт для ранжирования с учётом неразмещённых элементов"""
        
        items = active_list.items
        n_items = len(items)
        
        if n_items == 0:
            raise ValueError("List is empty")
        
        scores = {item.id: 0 for item in items}
        voted_count = 0
        
        for p in session.participants:
            if p.status != ParticipantStatus.ACCEPTED:
                continue
            if not p.has_voted:
                # Не голосовал — все элементы получают 1 очко (последнее место)
                for item in items:
                    scores[item.id] += 1
                continue
            
            voted_count += 1
            ranked_ids = p.vote_data.get("ranked_ids", []) if p.vote_data else []
            
            # Размещённые элементы
            for position, item_id in enumerate(ranked_ids):
                points = n_items - position
                scores[item_id] = scores.get(item_id, 0) + points
            
            # Неразмещённые элементы — последнее место (1 очко)
            ranked_set = set(ranked_ids)
            for item in items:
                if item.id not in ranked_set:
                    scores[item.id] = scores.get(item.id, 0) + 1
        
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
    
    # ============= Блокировка элементов =============
    
    async def lock_item_for_edit(self, item_id: int, user_id: int) -> SessionListItem:
        """Заблокировать элемент для редактирования"""
        
        item = await self.db.get(SessionListItem, item_id)
        if not item:
            raise ValueError("Item not found")
        
        # Проверяем, не редактирует ли кто-то другой
        if item.edited_by and item.edited_by != user_id:
            if item.edited_at:
                elapsed = (datetime.now(timezone.utc) - item.edited_at).total_seconds()
                if elapsed < 30:  # Блокировка на 30 секунд
                    editor = await self.db.get(User, item.edited_by)
                    editor_name = editor.username if editor else "Unknown"
                    raise ValueError(f"Участник {editor_name} уже редактирует этот элемент")
        
        item.edited_by = user_id
        item.edited_at = datetime.now(timezone.utc)
        await self.db.commit()
        await self.db.refresh(item)
        
        return item
    
    async def unlock_item(self, item_id: int, user_id: int) -> SessionListItem:
        """Разблокировать элемент"""
        
        item = await self.db.get(SessionListItem, item_id)
        if not item:
            raise ValueError("Item not found")
        
        if item.edited_by == user_id:
            item.edited_by = None
            item.edited_at = None
            await self.db.commit()
            await self.db.refresh(item)
        
        return item
    
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
        session.countdown_ends_at = None  # Сбрасываем таймер готовности
        
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
                editor_name = None
                if item.edited_by:
                    editor = await self.db.get(User, item.edited_by)
                    editor_name = editor.username if editor else None
                
                creator_name = await self.list_service.get_creator_name(item)
                items.append({
                    "id": item.id,
                    "name": item.name,
                    "description": item.description,
                    "image_url": item.image_url,
                    "order_index": item.order_index,
                    "created_by": item.created_by,
                    "creator_name": creator_name,
                    "edited_by": item.edited_by,
                    "editor_name": editor_name
                })
            
            list_data = {
                "id": active_list.id,
                "name": active_list.name,
                "is_active": active_list.is_active,
                "items": items,
                "created_at": active_list.created_at
            }
        
        owner = await self.db.get(User, session.owner_id)
        
        can_edit_list = (
            not session.list_locked and
            session.status in [SessionStatus.EDITING, SessionStatus.READY]
        )
        can_start = (
            is_owner and
            session.status in [SessionStatus.EDITING, SessionStatus.READY]
        )
        can_invite = (
            is_owner and
            session.status in [SessionStatus.WAITING, SessionStatus.EDITING, SessionStatus.READY]
        )
        can_lock_list = (
            is_owner and
            session.status in [SessionStatus.EDITING, SessionStatus.READY]
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
            "countdown_ends_at": session.countdown_ends_at,
            "voting_ends_at": session.voting_ends_at,
            "created_at": session.created_at,
            "results": session.results_json,
            "is_owner": is_owner,
            "can_edit_list": can_edit_list,
            "can_start": can_start,
            "can_invite": can_invite,
            "can_lock_list": can_lock_list
        }
    
    async def get_my_lobbies(self, user_id: int) -> Dict[str, List]:
        """Получить все лобби пользователя"""
        
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