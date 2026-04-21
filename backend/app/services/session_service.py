# app/services/session_service.py (обновлённая версия)
import asyncio
import random
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any, Tuple

from sqlalchemy import select, and_, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.session import (
    Session, SessionParticipant, SessionResult, 
    SessionStatus, SessionMode, SessionList, SessionListItem
)
from app.models.group import GroupMember
from app.models.user import User
from app.services.session_list_service import SessionListService


class SessionService:
    """Сервис для управления сессиями голосования"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.list_service = SessionListService(db)

    async def create_session(
        self,
        group_id: int,
        original_list_id: int,
        mode: SessionMode,
        created_by: int,
        countdown_duration: int = 60,
        voting_duration: int = 120
    ) -> Session:
        """
        Создать новую сессию голосования с временным списком.
        """
        # Проверяем, что нет активной сессии в этой группе
        active_session = await self.db.execute(
            select(Session).where(
                and_(
                    Session.group_id == group_id,
                    Session.status.in_([
                        SessionStatus.LOBBY_EDITING,
                        SessionStatus.LOBBY_COUNTDOWN,
                        SessionStatus.VOTING,
                        SessionStatus.RESULTS
                    ])
                )
            )
        )
        if active_session.scalar_one_or_none():
            raise ValueError("Group already has an active session")

        # Создаем сессию
        session = Session(
            group_id=group_id,
            original_list_id=original_list_id,
            created_by=created_by,
            mode=mode,
            status=SessionStatus.LOBBY_EDITING,
            countdown_duration=countdown_duration,
            voting_duration=voting_duration
        )
        self.db.add(session)
        await self.db.flush()

        # Создаём временный список
        await self.list_service.create_session_list(session.id, original_list_id)

        # Добавляем всех участников группы как участников сессии
        members_result = await self.db.execute(
            select(GroupMember).where(GroupMember.group_id == group_id)
        )
        members = members_result.scalars().all()

        for member in members:
            participant = SessionParticipant(
                session_id=session.id,
                user_id=member.user_id,
                is_ready=False  # Никто не готов изначально, даже создатель
            )
            self.db.add(participant)

        await self.db.commit()
        await self.db.refresh(session)

        return session

    async def mark_ready(self, session_id: int, user_id: int) -> Dict[str, Any]:
        """
        Отметить участника как готового.
        Если это первый готовый - запускает таймер.
        """
        session = await self._get_session(session_id)
        
        if session.status not in [SessionStatus.LOBBY_EDITING, SessionStatus.LOBBY_COUNTDOWN]:
            raise ValueError("Session is not in lobby state")

        participant = await self._get_participant(session_id, user_id)
        if participant.is_ready:
            return {"status": session.status.value, "already_ready": True}

        was_countdown = (session.status == SessionStatus.LOBBY_COUNTDOWN)
        
        participant.is_ready = True
        participant.ready_at = datetime.now(timezone.utc)
        
        # Если это первый готовый и таймер ещё не запущен
        if not was_countdown and session.status == SessionStatus.LOBBY_EDITING:
            # Проверяем, что это действительно первый
            ready_count = await self._count_ready_participants(session_id)
            if ready_count == 1:
                session.status = SessionStatus.LOBBY_COUNTDOWN
                now = datetime.now(timezone.utc)
                session.countdown_ends_at = now + timedelta(seconds=session.countdown_duration)
        
        await self.db.commit()
        await self.db.refresh(participant)

        # Проверяем, все ли готовы
        all_ready = await self._check_all_ready(session_id)
        if all_ready:
            await self._transition_to_voting(session_id)

        return {
            "status": session.status.value,
            "countdown_started": (not was_countdown and session.status == SessionStatus.LOBBY_COUNTDOWN),
            "all_ready": all_ready
        }

    async def submit_vote(
        self,
        session_id: int,
        user_id: int,
        ranked_item_ids: Optional[List[int]] = None,
        spin: bool = False
    ) -> Tuple[bool, Dict[str, Any]]:
        """
        Отправить голос.
        """
        session = await self._get_session(session_id)
        if session.status != SessionStatus.VOTING:
            raise ValueError("Session is not in voting state")

        participant = await self._get_participant(session_id, user_id)
        if participant.has_voted:
            raise ValueError("User has already voted")

        # Получаем временный список для валидации
        session_list = await self.list_service.get_session_list(session_id)
        if not session_list:
            raise ValueError("Session list not found")

        if session.mode == SessionMode.RANKING:
            if not ranked_item_ids:
                raise ValueError("ranked_item_ids required for ranking mode")
            
            # Проверяем, что все ID из временного списка
            valid_ids = {item.id for item in session_list.items}
            if set(ranked_item_ids) != valid_ids:
                raise ValueError(f"Ranked IDs must contain exactly all session list items. Expected {valid_ids}")
            
            participant.vote_data = {"ranked_ids": ranked_item_ids}
        elif session.mode == SessionMode.RANDOM:
            if not spin:
                raise ValueError("spin flag required for random mode")
            participant.has_spun = True
        else:
            raise ValueError(f"Unknown session mode: {session.mode}")

        participant.has_voted = True
        participant.voted_at = datetime.now(timezone.utc)
        await self.db.commit()

        all_voted = await self._check_all_voted(session_id)
        results = None

        if all_voted:
            results = await self._calculate_results(session_id)

        return all_voted, results

    async def reset_for_new_round(self, session_id: int, user_id: int) -> Session:
        """
        Сбросить сессию для нового раунда после показа результатов.
        Только создатель может сбросить.
        """
        session = await self._get_session(session_id)
        
        if session.status != SessionStatus.RESULTS:
            raise ValueError("Session is not in results state")
        
        if session.created_by != user_id:
            raise ValueError("Only session creator can reset for new round")
        
        # Сбрасываем статус
        session.status = SessionStatus.LOBBY_EDITING
        session.countdown_ends_at = None
        session.voting_ends_at = None
        session.results_json = None
        
        # Сбрасываем готовность и голоса участников
        await self.db.execute(
            update(SessionParticipant)
            .where(SessionParticipant.session_id == session_id)
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
        from sqlalchemy import delete
        await self.db.execute(
            delete(SessionResult).where(SessionResult.session_id == session_id)
        )
        
        await self.db.commit()
        await self.db.refresh(session)
        
        return session

    async def _calculate_results(self, session_id: int) -> Dict[str, Any]:
        """Подсчет результатов голосования."""
        session = await self._get_session(session_id, load_participants=True)
        session_list = await self.list_service.get_session_list(session_id)
        
        if not session_list:
            raise ValueError("Session list not found")

        if session.mode == SessionMode.RANDOM:
            results = await self._calculate_random_results(session, session_list)
        else:
            results = await self._calculate_ranking_results(session, session_list)

        session.results_json = results
        session.status = SessionStatus.RESULTS
        session.completed_at = datetime.now(timezone.utc)

        # Сохраняем в таблицу SessionResult
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
        session_list: SessionList
    ) -> Dict[str, Any]:
        """Подсчет результатов для режима ранжирования."""
        items = session_list.items
        n_items = len(items)

        if n_items == 0:
            raise ValueError("List has no items")

        scores = {item.id: 0 for item in items}

        for participant in session.participants:
            if not participant.has_voted or not participant.vote_data:
                continue

            ranked_ids = participant.vote_data.get("ranked_ids", [])
            if not ranked_ids:
                continue

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

        winner = results[0] if results else None

        return {
            "session_id": session.id,
            "mode": session.mode.value,
            "winner": winner,
            "results": results
        }

    async def _calculate_random_results(
        self, 
        session: Session, 
        session_list: SessionList
    ) -> Dict[str, Any]:
        """Подсчет результатов для режима колеса."""
        items = session_list.items

        if not items:
            raise ValueError("List has no items")

        winner_item = random.choice(items)

        results = []
        for place, item in enumerate(items, 1):
            results.append({
                "item_id": item.id,
                "item_name": item.name,
                "total_score": 1 if item.id == winner_item.id else 0,
                "place": place if item.id != winner_item.id else 1
            })

        results.sort(key=lambda x: (x["place"] != 1, x["place"]))

        return {
            "session_id": session.id,
            "mode": session.mode.value,
            "winner": {
                "item_id": winner_item.id,
                "item_name": winner_item.name,
                "total_score": 1,
                "place": 1
            },
            "results": results
        }

    async def _check_all_ready(self, session_id: int) -> bool:
        """Проверить, все ли участники отметились готовыми."""
        result = await self.db.execute(
            select(SessionParticipant).where(
                and_(
                    SessionParticipant.session_id == session_id,
                    SessionParticipant.is_ready == False
                )
            )
        )
        not_ready = result.scalars().all()
        return len(not_ready) == 0

    async def _count_ready_participants(self, session_id: int) -> int:
        """Посчитать количество готовых участников."""
        result = await self.db.execute(
            select(SessionParticipant).where(
                and_(
                    SessionParticipant.session_id == session_id,
                    SessionParticipant.is_ready == True
                )
            )
        )
        return len(result.scalars().all())

    async def _check_all_voted(self, session_id: int) -> bool:
        """Проверить, все ли участники проголосовали."""
        result = await self.db.execute(
            select(SessionParticipant).where(
                and_(
                    SessionParticipant.session_id == session_id,
                    SessionParticipant.has_voted == False
                )
            )
        )
        not_voted = result.scalars().all()
        return len(not_voted) == 0

    async def _transition_to_voting(self, session_id: int) -> None:
        """Перевести сессию в состояние голосования."""
        session = await self._get_session(session_id)
        now = datetime.now(timezone.utc)

        session.status = SessionStatus.VOTING
        session.voting_ends_at = now + timedelta(seconds=session.voting_duration)

        await self.db.commit()

    async def _get_session(
        self, 
        session_id: int, 
        load_participants: bool = False
    ) -> Session:
        """Получить сессию по ID."""
        query = select(Session).where(Session.id == session_id)

        if load_participants:
            query = query.options(selectinload(Session.participants))

        result = await self.db.execute(query)
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError(f"Session {session_id} not found")
        return session

    async def _get_participant(self, session_id: int, user_id: int) -> SessionParticipant:
        """Получить запись участника сессии."""
        result = await self.db.execute(
            select(SessionParticipant).where(
                and_(
                    SessionParticipant.session_id == session_id,
                    SessionParticipant.user_id == user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        if not participant:
            raise ValueError(f"User {user_id} is not a participant of session {session_id}")
        return participant

    async def get_session_detail(self, session_id: int, user_id: int) -> Dict[str, Any]:
        """Получить детальную информацию о сессии."""
        session = await self._get_session(session_id, load_participants=True)

        participant = next(
            (p for p in session.participants if p.user_id == user_id), 
            None
        )
        if not participant:
            raise ValueError("User is not a participant of this session")

        participants_info = []
        for p in session.participants:
            user_result = await self.db.execute(
                select(User).where(User.id == p.user_id)
            )
            user = user_result.scalar_one()
            participants_info.append({
                "user_id": p.user_id,
                "username": user.username,
                "is_ready": p.is_ready,
                "has_voted": p.has_voted,
                "has_spun": p.has_spun,
                "is_creator": (p.user_id == session.created_by),
                "joined_at": p.joined_at,
                "ready_at": p.ready_at
            })

        # Получаем временный список
        session_list = await self.list_service.get_session_list(session_id)
        list_data = None
        if session_list:
            items_data = []
            for item in session_list.items:
                creator_name = await self.list_service.get_item_creator_name(item)
                items_data.append({
                    "id": item.id,
                    "name": item.name,
                    "description": item.description,
                    "image_url": item.image_url,
                    "order_index": item.order_index,
                    "created_by": item.created_by,
                    "creator_name": creator_name
                })
            list_data = {
                "id": session_list.id,
                "session_id": session_list.session_id,
                "name": session_list.name,
                "items": items_data,
                "created_at": session_list.created_at,
                "updated_at": session_list.updated_at
            }

        # Определяем, может ли пользователь редактировать список
        can_edit = (
            session.status in [SessionStatus.LOBBY_EDITING, SessionStatus.LOBBY_COUNTDOWN]
            and not participant.is_ready  # Кто нажал "Готов" - не может редактировать
        )

        return {
            "id": session.id,
            "group_id": session.group_id,
            "original_list_id": session.original_list_id,
            "created_by": session.created_by,
            "mode": session.mode.value,
            "status": session.status.value,
            "countdown_duration": session.countdown_duration,
            "voting_duration": session.voting_duration,
            "started_at": session.started_at,
            "countdown_ends_at": session.countdown_ends_at,
            "voting_ends_at": session.voting_ends_at,
            "completed_at": session.completed_at,
            "created_at": session.created_at,
            "participants": participants_info,
            "session_list": list_data,
            "results": session.results_json,
            "can_edit": can_edit,
            "is_creator": (session.created_by == user_id)
        }

    async def check_timers_and_transition(self) -> List[int]:
        """Проверить все активные сессии на истечение таймеров."""
        now = datetime.now(timezone.utc)
        updated_sessions = []

        # Сессии в отсчёте с истекшим таймером
        expired_countdown = await self.db.execute(
            select(Session).where(
                and_(
                    Session.status == SessionStatus.LOBBY_COUNTDOWN,
                    Session.countdown_ends_at <= now
                )
            )
        )
        for session in expired_countdown.scalars().all():
            await self._transition_to_voting(session.id)
            updated_sessions.append(session.id)

        # Сессии в голосовании с истекшим таймером
        expired_voting = await self.db.execute(
            select(Session).where(
                and_(
                    Session.status == SessionStatus.VOTING,
                    Session.voting_ends_at <= now
                )
            )
        )
        for session in expired_voting.scalars().all():
            await self._calculate_results(session.id)
            updated_sessions.append(session.id)

        await self.db.commit()
        return updated_sessions