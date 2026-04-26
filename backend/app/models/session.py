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
    WAITING = "waiting"
    EDITING = "editing"
    READY = "ready"
    VOTING = "voting"
    RESULTS = "results"
    CLOSED = "closed"


class SessionMode(str, enum.Enum):
    """Режимы голосования"""
    RANDOM = "random"
    RANKING = "ranking"


class ParticipantStatus(str, enum.Enum):
    """Статус участника в сессии"""
    INVITED = "invited"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    LEFT = "left"
    KICKED = "kicked"


class Session(Base):
    """Сессия голосования (лобби)"""
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    current_list_id = Column(Integer, ForeignKey("session_lists.id", ondelete="SET NULL"), nullable=True)
    
    mode = Column(Enum(SessionMode), nullable=False, default=SessionMode.RANKING)
    status = Column(Enum(SessionStatus), default=SessionStatus.WAITING, nullable=False)
    
    list_locked = Column(Boolean, default=False)
    
    voting_duration = Column(Integer, default=120)
    
    # Таймер готовности (когда заканчивается)
    countdown_ends_at = Column(DateTime(timezone=True), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True), nullable=True)
    voting_ends_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    closed_at = Column(DateTime(timezone=True), nullable=True)
    closed_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    results_json = Column(JSON, nullable=True)
    
    # Отношения
    owner = relationship("User", foreign_keys=[owner_id], backref="owned_sessions")
    closer = relationship("User", foreign_keys=[closed_by])
    
    session_lists = relationship(
        "SessionList", 
        back_populates="session",
        foreign_keys="SessionList.session_id",
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
    name = Column(String(100), nullable=False)
    
    is_active = Column(Boolean, default=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Отношения
    session = relationship(
        "Session", 
        back_populates="session_lists",
        foreign_keys=[session_id]
    )
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
    
    # Блокировка редактирования
    edited_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    edited_at = Column(DateTime(timezone=True), nullable=True)
    
    # Отношения
    session_list = relationship("SessionList", back_populates="items")
    creator = relationship("User", foreign_keys=[created_by])
    editor = relationship("User", foreign_keys=[edited_by])


class SessionParticipant(Base):
    """Участник сессии"""
    __tablename__ = "session_participants"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    status = Column(Enum(ParticipantStatus), default=ParticipantStatus.INVITED, nullable=False)
    
    is_ready = Column(Boolean, default=False)
    has_voted = Column(Boolean, default=False)
    vote_data = Column(JSON, nullable=True)
    has_spun = Column(Boolean, default=False)
    
    invited_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
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