# app/schemas/session.py
from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum


# ============= Enums =============
class SessionStatusEnum(str, Enum):
    WAITING = "waiting"
    EDITING = "editing"
    READY = "ready"
    VOTING = "voting"
    RESULTS = "results"
    CLOSED = "closed"


class SessionModeEnum(str, Enum):
    RANDOM = "random"
    RANKING = "ranking"


class ParticipantStatusEnum(str, Enum):
    INVITED = "invited"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    LEFT = "left"
    KICKED = "kicked"


# ============= Request Schemas =============
class LobbyListItem(BaseModel):
    """Пункт списка при создании лобби"""
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    image_url: Optional[str] = None
    order_index: int = 0

class LobbyListData(BaseModel):
    """Данные списка при создании лобби"""
    name: str = Field(..., min_length=1, max_length=100)
    items: List[LobbyListItem] = Field(..., min_length=1, max_length=100)


class CreateLobbyRequest(BaseModel):
    """Запрос на создание лобби"""
    friend_ids: List[int] = Field(..., min_length=1, max_length=20)
    list_data: LobbyListData              # <-- теперь весь список
    mode: SessionModeEnum = SessionModeEnum.RANKING
    voting_duration: int = Field(default=120, ge=30, le=600)


class ChangeListRequest(BaseModel):
    """Смена списка в лобби"""
    list_id: int


class InviteToLobbyRequest(BaseModel):
    """Пригласить ещё друзей"""
    friend_ids: List[int]


class AcceptInviteRequest(BaseModel):
    """Принять приглашение"""
    pass


class DeclineInviteRequest(BaseModel):
    """Отклонить приглашение"""
    pass


class MarkReadyRequest(BaseModel):
    """Отметка готовности"""
    pass


class StartLobbyRequest(BaseModel):
    """Принудительный старт владельцем"""
    pass


class LockListRequest(BaseModel):
    """Закрыть список для редактирования"""
    pass


class UnlockListRequest(BaseModel):
    """Открыть список для редактирования"""
    pass


class VoteRequest(BaseModel):
    """Отправка голоса"""
    ranked_item_ids: Optional[List[int]] = None
    spin: bool = False

    @field_validator('ranked_item_ids')
    def check_duplicates(cls, v):
        if v is not None and len(v) != len(set(v)):
            raise ValueError('Duplicate item IDs are not allowed')
        return v


class SessionListItemCreate(BaseModel):
    """Добавление пункта в список"""
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    image_url: Optional[str] = None


class SessionListItemUpdate(BaseModel):
    """Обновление пункта"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    image_url: Optional[str] = None


class ItemsOrderUpdate(BaseModel):
    """Обновление порядка пунктов"""
    items: List[Dict[str, int]]


# ============= Response Schemas =============
class SessionListItemResponse(BaseModel):
    """Пункт списка"""
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
    """Список в лобби"""
    id: int
    name: str
    is_active: bool
    items: List[SessionListItemResponse]
    created_at: datetime
    
    class Config:
        from_attributes = True


class ParticipantResponse(BaseModel):
    """Участник лобби"""
    user_id: int
    username: str
    status: ParticipantStatusEnum
    is_ready: bool
    has_voted: bool
    is_owner: bool
    invited_at: datetime
    joined_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class LobbyResponse(BaseModel):
    """Информация о лобби"""
    id: int
    owner_id: int
    owner_name: str
    status: SessionStatusEnum
    mode: SessionModeEnum
    list_locked: bool
    current_list: Optional[SessionListResponse] = None
    participants: List[ParticipantResponse]
    voting_duration: int
    created_at: datetime
    voting_ends_at: Optional[datetime] = None
    results: Optional[Dict[str, Any]] = None
    
    # Права текущего пользователя
    is_owner: bool = False
    can_edit_list: bool = False
    can_start: bool = False
    can_invite: bool = False
    can_lock_list: bool = False
    
    class Config:
        from_attributes = True


class MyLobbiesResponse(BaseModel):
    """Список лобби пользователя"""
    active: List[LobbyResponse]
    invitations: List[LobbyResponse]
    history: List[LobbyResponse]


class VoteResultResponse(BaseModel):
    """Результат голосования"""
    success: bool
    message: str
    all_voted: bool = False


class ResultsResponse(BaseModel):
    """Результаты голосования"""
    session_id: int
    winner: Optional[Dict[str, Any]] = None
    results: List[Dict[str, Any]]
    participants_count: int
    voted_count: int


# ============= WebSocket Schemas =============
class WSMessageType(str, Enum):
    """Типы WebSocket сообщений"""
    # От сервера
    LOBBY_INVITATION = "lobby_invitation"
    PARTICIPANT_JOINED = "participant_joined"
    PARTICIPANT_LEFT = "participant_left"
    PARTICIPANT_READY = "participant_ready"
    LIST_CHANGED = "list_changed"
    LIST_LOCKED = "list_locked"
    LIST_UNLOCKED = "list_unlocked"
    LIST_ITEM_ADDED = "list_item_added"
    LIST_ITEM_UPDATED = "list_item_updated"
    LIST_ITEM_DELETED = "list_item_deleted"
    LIST_ORDER_CHANGED = "list_order_changed"
    LOBBY_STARTED = "lobby_started"
    VOTING_STARTED = "voting_started"
    USER_VOTED = "user_voted"
    RESULTS_READY = "results_ready"
    LOBBY_CLOSED = "lobby_closed"
    STATE_CHANGED = "state_changed"
    ERROR = "error"
    PONG = "pong"
    NAVIGATE_TO_LOBBY = "navigate_to_lobby"
    NAVIGATE_TO_HOME = "navigate_to_home"
    NAVIGATE_TO_RANKING = "navigate_to_ranking"
    NAVIGATE_TO_RESULTS = "navigate_to_results"
    TIMER_UPDATED = "timer_updated"
    PARTICIPANT_KICKED = "participant_kicked"
    ITEM_LOCKED = "item_locked"
    ITEM_UNLOCKED = "item_unlocked"
    UNREADY = "unready"
    KICK_PARTICIPANT = "kick_participant"
    LOCK_ITEM = "lock_item"
    UNLOCK_ITEM = "unlock_item"
    
    # От клиента
    ACCEPT_INVITE = "accept_invite"
    DECLINE_INVITE = "decline_invite"
    READY = "ready"
    START_LOBBY = "start_lobby"
    CHANGE_LIST = "change_list"
    LOCK_LIST = "lock_list"
    UNLOCK_LIST = "unlock_list"
    ADD_ITEM = "add_item"
    UPDATE_ITEM = "update_item"
    DELETE_ITEM = "delete_item"
    UPDATE_ORDER = "update_order"
    VOTE = "vote"
    LEAVE_LOBBY = "leave_lobby"
    CLOSE_LOBBY = "close_lobby"
    BACK_TO_LOBBY = "back_to_lobby"
    PING = "ping"


class WSMessage(BaseModel):
    """Сообщение WebSocket"""
    type: str
    payload: Dict[str, Any] = Field(default_factory=dict)