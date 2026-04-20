# app/models/session.py
from sqlalchemy import (
    Column, Integer, String, ForeignKey, DateTime, 
    Enum, JSON, Boolean, CheckConstraint, UniqueConstraint, Text
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
import enum


class SessionStatus(str, enum.Enum):
    """Статусы сессии голосования"""
    LOBBY_EDITING = "lobby_editing"      # Редактирование списка, таймер стоит
    LOBBY_COUNTDOWN = "lobby_countdown"  # Таймер идёт после первого "Готов"
    VOTING = "voting"                    # Активное голосование
    RESULTS = "results"                  # Результаты подсчитаны
    CANCELLED = "cancelled"              # Отменена


class SessionMode(str, enum.Enum):
    """Режимы выбора"""
    RANDOM = "random"    # Колесо фортуны
    RANKING = "ranking"  # Ранжирование


class Session(Base):
    """Сессия голосования в группе"""
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False)
    original_list_id = Column(Integer, ForeignKey("lists.id", ondelete="SET NULL"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    mode = Column(Enum(SessionMode), nullable=False)
    status = Column(Enum(SessionStatus), default=SessionStatus.LOBBY_EDITING, nullable=False)

    # Таймеры (в секундах)
    countdown_duration = Column(Integer, default=60)  # Время после первого "Готов"
    voting_duration = Column(Integer, default=120)     # Время на голосование

    started_at = Column(DateTime(timezone=True), server_default=func.now())
    countdown_ends_at = Column(DateTime(timezone=True), nullable=True)
    voting_ends_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    # JSON с итоговыми результатами
    results_json = Column(JSON, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Отношения
    group = relationship("Group", foreign_keys=[group_id])
    original_list = relationship("ItemList", foreign_keys=[original_list_id])
    creator = relationship("User", foreign_keys=[created_by])
    
    # Временный список для сессии (один к одному)
    session_list = relationship(
        "SessionList", 
        back_populates="session", 
        uselist=False,
        cascade="all, delete-orphan"
    )
    
    participants = relationship(
        "SessionParticipant", 
        back_populates="session", 
        cascade="all, delete-orphan"
    )
    results = relationship(
        "SessionResult", 
        back_populates="session", 
        cascade="all, delete-orphan"
    )


class SessionList(Base):
    """Временный список для сессии"""
    __tablename__ = "session_lists"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, unique=True)
    original_list_id = Column(Integer, ForeignKey("lists.id", ondelete="SET NULL"), nullable=True)
    name = Column(String(100), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Отношения
    session = relationship("Session", back_populates="session_list")
    original_list = relationship("ItemList", foreign_keys=[original_list_id])
    items = relationship(
        "SessionListItem", 
        back_populates="session_list", 
        cascade="all, delete-orphan",
        order_by="SessionListItem.order_index"
    )


class SessionListItem(Base):
    """Пункт временного списка сессии"""
    __tablename__ = "session_list_items"
    
    id = Column(Integer, primary_key=True, index=True)
    session_list_id = Column(Integer, ForeignKey("session_lists.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    image_url = Column(String(500), nullable=True)
    order_index = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Кто добавил/изменил (опционально)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Отношения
    session_list = relationship("SessionList", back_populates="items")
    creator = relationship("User", foreign_keys=[created_by])


class SessionParticipant(Base):
    """Участник сессии и его действия"""
    __tablename__ = "session_participants"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    is_ready = Column(Boolean, default=False, nullable=False)
    has_voted = Column(Boolean, default=False, nullable=False)

    # Для режима ранжирования: сохраняем порядок ID пунктов
    vote_data = Column(JSON, nullable=True)

    # Для режима колеса: сохраняем просто факт "крутанул"
    has_spun = Column(Boolean, default=False, nullable=False)

    joined_at = Column(DateTime(timezone=True), server_default=func.now())
    ready_at = Column(DateTime(timezone=True), nullable=True)
    voted_at = Column(DateTime(timezone=True), nullable=True)

    # Отношения
    session = relationship("Session", back_populates="participants")
    user = relationship("User", foreign_keys=[user_id])

    __table_args__ = (
        UniqueConstraint('session_id', 'user_id', name='uq_session_participant'),
    )


class SessionResult(Base):
    """Результаты голосования по каждому пункту списка"""
    __tablename__ = "session_results"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    session_list_item_id = Column(Integer, ForeignKey("session_list_items.id", ondelete="CASCADE"), nullable=False)

    total_score = Column(Integer, default=0, nullable=False)
    place = Column(Integer, nullable=True)

    # Отношения
    session = relationship("Session", back_populates="results")
    list_item = relationship("SessionListItem", foreign_keys=[session_list_item_id])

    __table_args__ = (
        UniqueConstraint('session_id', 'session_list_item_id', name='uq_session_result'),
    )   