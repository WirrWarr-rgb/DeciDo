# app/schemas/session.py
from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum


# ============= Enums =============
class SessionStatusEnum(str, Enum):
    LOBBY_EDITING = "lobby_editing"
    LOBBY_COUNTDOWN = "lobby_countdown"
    VOTING = "voting"
    RESULTS = "results"
    CANCELLED = "cancelled"


class SessionModeEnum(str, Enum):
    RANDOM = "random"
    RANKING = "ranking"


# ============= Request Schemas =============
class SessionCreate(BaseModel):
    """Создание новой сессии"""
    group_id: int
    list_id: int  # ID оригинального списка пользователя
    mode: SessionModeEnum
    countdown_duration: int = Field(default=60, ge=10, le=300)  # 10 сек - 5 мин
    voting_duration: int = Field(default=120, ge=30, le=600)     # 30 сек - 10 мин


class SessionListItemCreate(BaseModel):
    """Добавление пункта во временный список"""
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    image_url: Optional[str] = None


class SessionListItemUpdate(BaseModel):
    """Обновление пункта временного списка"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    image_url: Optional[str] = None


class SessionListOrderUpdate(BaseModel):
    """Обновление порядка пунктов"""
    items: List[Dict[str, int]]  # [{"id": 1, "order_index": 0}, ...]


class ReadyRequest(BaseModel):
    """Отметка о готовности"""
    pass


class VoteRequest(BaseModel):
    """Отправка голоса"""
    ranked_item_ids: Optional[List[int]] = None  # ID пунктов SessionListItem
    spin: bool = False

    @field_validator('ranked_item_ids')
    def check_duplicates(cls, v):
        if v is not None and len(v) != len(set(v)):
            raise ValueError('Duplicate item IDs are not allowed')
        return v


class ResetSessionRequest(BaseModel):
    """Сброс сессии для нового раунда"""
    pass


# ============= Response Schemas =============
class SessionListItemResponse(BaseModel):
    """Пункт временного списка"""
    id: int
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    order_index: int
    created_by: Optional[int] = None
    creator_name: Optional[str] = None
    
    class Config:
        from_attributes = True


class SessionListResponse(BaseModel):
    """Временный список сессии"""
    id: int
    session_id: int
    name: str
    items: List[SessionListItemResponse]
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class SessionParticipantResponse(BaseModel):
    """Информация об участнике сессии"""
    user_id: int
    username: str
    is_ready: bool
    has_voted: bool
    has_spun: bool
    is_creator: bool
    joined_at: datetime
    ready_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SessionResponse(BaseModel):
    """Базовая информация о сессии"""
    id: int
    group_id: int
    original_list_id: Optional[int] = None
    created_by: Optional[int] = None
    mode: SessionModeEnum
    status: SessionStatusEnum
    countdown_duration: int
    voting_duration: int
    started_at: datetime
    countdown_ends_at: Optional[datetime] = None
    voting_ends_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class SessionDetailResponse(SessionResponse):
    """Детальная информация о сессии"""
    participants: List[SessionParticipantResponse]
    session_list: Optional[SessionListResponse] = None
    results: Optional[Dict[str, Any]] = None
    can_edit: bool  # Может ли текущий пользователь редактировать список
    is_creator: bool  # Является ли текущий пользователь создателем


class VoteResultResponse(BaseModel):
    """Результат обработки голоса"""
    success: bool
    message: str
    all_voted: bool = False


class SessionResultItemResponse(BaseModel):
    """Результат по одному пункту"""
    item_id: int
    item_name: str
    total_score: int
    place: int


class SessionResultsResponse(BaseModel):
    """Полные результаты сессии"""
    session_id: int
    status: SessionStatusEnum
    winner: Optional[SessionResultItemResponse] = None
    results: List[SessionResultItemResponse]


# ============= WebSocket Schemas =============
class WSMessageType(str, Enum):
    """Типы сообщений WebSocket"""
    # От сервера к клиенту
    USER_READY = "user_ready"
    USER_VOTED = "user_voted"
    SESSION_STATE_CHANGED = "session_state_changed"
    LIST_UPDATED = "list_updated"           # Список изменён
    LIST_ITEM_ADDED = "list_item_added"     # Добавлен пункт
    LIST_ITEM_UPDATED = "list_item_updated" # Обновлён пункт
    LIST_ITEM_DELETED = "list_item_deleted" # Удалён пункт
    TIMER_SYNC = "timer_sync"
    COUNTDOWN_STARTED = "countdown_started"  # Таймер запущен
    RESULTS_READY = "results_ready"
    ERROR = "error"
    PONG = "pong"

    # От клиента к серверу
    READY = "ready"
    VOTE = "vote"
    PING = "ping"
    UPDATE_LIST_ITEM = "update_list_item"
    ADD_LIST_ITEM = "add_list_item"
    DELETE_LIST_ITEM = "delete_list_item"
    UPDATE_ITEM_ORDER = "update_item_order"


class WSMessage(BaseModel):
    """Структура сообщения WebSocket"""
    type: str
    payload: Dict[str, Any] = Field(default_factory=dict)