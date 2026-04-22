# app/models/session.py
from sqlalchemy import (
    Column, Integer, String, ForeignKey, DateTime, 
    Enum, JSON, Boolean, Text
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
import enum


class SessionStatus(str, enum.Enum):
    """Статусы сессии"""
    WAITING = "waiting"          # Ожидание принятия приглашений
    EDITING = "editing"          # Редактирование списка
    READY = "ready"              # Владелец нажал "Начать", скоро голосование
    VOTING = "voting"            # Активное голосование
    RESULTS = "results"          # Результаты показаны
    CLOSED = "closed"            # Закрыто владельцем


class SessionMode(str, enum.Enum):
    """Режимы голосования"""
    RANDOM = "random"    # Колесо фортуны
    RANKING = "ranking"  # Ранжирование


class ParticipantStatus(str, enum.Enum):
    """Статус участника в сессии"""
    INVITED = "invited"      # Приглашён, ещё не ответил
    ACCEPTED = "accepted"    # Принял приглашение
    DECLINED = "declined"    # Отклонил приглашение
    LEFT = "left"            # Вышел из лобби


class Session(Base):
    """Сессия голосования (лобби)"""
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Текущий активный список (из session_lists)
    current_list_id = Column(Integer, ForeignKey("session_lists.id", ondelete="SET NULL"), nullable=True)
    
    mode = Column(Enum(SessionMode), nullable=False, default=SessionMode.RANKING)
    status = Column(Enum(SessionStatus), default=SessionStatus.WAITING, nullable=False)
    
    # Флаги
    list_locked = Column(Boolean, default=False)   # Список закрыт для редактирования
    auto_start = Column(Boolean, default=False)    # Начать без ожидания готовности
    
    # Таймеры (в секундах)
    voting_duration = Column(Integer, default=120)  # Время на голосование
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True), nullable=True)   # Когда началось голосование
    voting_ends_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    closed_at = Column(DateTime(timezone=True), nullable=True)
    closed_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # JSON с итоговыми результатами
    results_json = Column(JSON, nullable=True)
    
    # Отношения
    owner = relationship("User", foreign_keys=[owner_id], backref="owned_sessions")
    closer = relationship("User", foreign_keys=[closed_by])
    
    session_lists = relationship(
        "SessionList", 
        back_populates="session",
        cascade="all, delete-orphan"
    )
    
    current_list = relationship(
        "SessionList", 
        foreign_keys=[current_list_id],
        post_update=True
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
    """Список, используемый в сессии (может быть несколько)"""
    __tablename__ = "session_lists"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    original_list_id = Column(Integer, ForeignKey("lists.id", ondelete="SET NULL"), nullable=True)
    name = Column(String(100), nullable=False)
    
    # Это активный список?
    is_active = Column(Boolean, default=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Отношения
    session = relationship("Session", back_populates="session_lists")
    original_list = relationship("ItemList", foreign_keys=[original_list_id])
    items = relationship(
        "SessionListItem", 
        back_populates="session_list", 
        cascade="all, delete-orphan",
        order_by="SessionListItem.order_index"
    )


class SessionListItem(Base):
    """Пункт списка сессии"""
    __tablename__ = "session_list_items"
    
    id = Column(Integer, primary_key=True, index=True)
    session_list_id = Column(Integer, ForeignKey("session_lists.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    image_url = Column(String(500), nullable=True)
    order_index = Column(Integer, default=0)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Отношения
    session_list = relationship("SessionList", back_populates="items")
    creator = relationship("User", foreign_keys=[created_by])


class SessionParticipant(Base):
    """Участник сессии"""
    __tablename__ = "session_participants"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Статус участника
    status = Column(Enum(ParticipantStatus), default=ParticipantStatus.INVITED, nullable=False)
    
    # Для голосования
    is_ready = Column(Boolean, default=False)
    has_voted = Column(Boolean, default=False)
    vote_data = Column(JSON, nullable=True)
    has_spun = Column(Boolean, default=False)
    
    # Кто пригласил
    invited_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Временные метки
    invited_at = Column(DateTime(timezone=True), server_default=func.now())
    joined_at = Column(DateTime(timezone=True), nullable=True)
    ready_at = Column(DateTime(timezone=True), nullable=True)
    voted_at = Column(DateTime(timezone=True), nullable=True)
    left_at = Column(DateTime(timezone=True), nullable=True)
    
    # Отношения
    session = relationship("Session", back_populates="participants")
    user = relationship("User", foreign_keys=[user_id])
    inviter = relationship("User", foreign_keys=[invited_by])


class SessionResult(Base):
    """Результаты голосования"""
    __tablename__ = "session_results"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    session_list_item_id = Column(Integer, ForeignKey("session_list_items.id", ondelete="CASCADE"), nullable=False)
    
    total_score = Column(Integer, default=0)
    place = Column(Integer, nullable=True)
    
    # Отношения
    session = relationship("Session", back_populates="results")
    list_item = relationship("SessionListItem", foreign_keys=[session_list_item_id])