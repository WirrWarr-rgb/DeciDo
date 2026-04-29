# app/tasks/session_tasks.py (обновлённая версия)
import asyncio
from celery import Celery
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, and_
from datetime import datetime, timezone

from app.core.config import settings
from app.services.session_service import SessionService
from app.models.session import Session, SessionStatus
from app.websocket.manager import manager

celery_app = Celery(
    "decido_tasks",
    broker=getattr(settings, 'CELERY_BROKER_URL', 'redis://localhost:6379/0'),
    backend=getattr(settings, 'CELERY_RESULT_BACKEND', 'redis://localhost:6379/1')
)

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    beat_schedule={
        'check-session-timers': {
            'task': 'app.tasks.session_tasks.check_session_timers',
            'schedule': 5.0,
        },
        'cleanup-inactive-sessions': {
            'task': 'app.tasks.session_tasks.cleanup_inactive_sessions',
            'schedule': 3600.0,  # Раз в час
        },
    }
)

engine = create_async_engine(settings.DATABASE_URL)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def _check_timers_async():
    async with AsyncSessionLocal() as db:
        session_service = SessionService(db)
        updated_sessions = await session_service.check_countdowns_and_transition()
        
        for session_id in updated_sessions:
            try:
                session = await session_service._get_session(session_id, load_participants=True)
                
                if session.status == SessionStatus.VOTING:
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": "voting_started",
                            "payload": {
                                "session_id": session_id,
                                "voting_ends_at": session.voting_ends_at.isoformat() if session.voting_ends_at else None
                            }
                        }
                    )
                
                elif session.status == SessionStatus.RESULTS and session.results_json:
                    await manager.broadcast_to_session(
                        session_id,
                        {
                            "type": "results_ready",
                            "payload": session.results_json
                        }
                    )
            except Exception as e:
                print(f"Error broadcasting for session {session_id}: {e}")
    
    return updated_sessions


async def _cleanup_inactive_async():
    """Удалить сессии, которые давно не активны."""
    async with AsyncSessionLocal() as db:
        # Находим сессии в статусе LOBBY_EDITING старше 2 часов
        two_hours_ago = datetime.now(timezone.utc) - timedelta(hours=2)
        
        result = await db.execute(
            select(Session).where(
                and_(
                    Session.status == SessionStatus.LOBBY_EDITING,
                    Session.started_at < two_hours_ago
                )
            )
        )
        inactive_sessions = result.scalars().all()
        
        for session in inactive_sessions:
            session.status = SessionStatus.CANCELLED
            await manager.broadcast_to_session(
                session.id,
                {
                    "type": "session_cancelled",
                    "payload": {
                        "session_id": session.id,
                        "reason": "inactivity"
                    }
                }
            )
        
        await db.commit()
        return len(inactive_sessions)


@celery_app.task(name='app.tasks.session_tasks.check_session_timers')
def check_session_timers():
    """Периодическая задача для проверки таймеров сессий."""
    loop = asyncio.get_event_loop()
    if loop.is_closed():
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    
    updated = loop.run_until_complete(_check_timers_async())
    return {"updated_sessions": updated}


@celery_app.task(name='app.tasks.session_tasks.cleanup_inactive_sessions')
def cleanup_inactive_sessions():
    """Удаление неактивных сессий."""
    from datetime import timedelta
    
    loop = asyncio.get_event_loop()
    if loop.is_closed():
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    
    cleaned = loop.run_until_complete(_cleanup_inactive_async())
    return {"cleaned_sessions": cleaned}