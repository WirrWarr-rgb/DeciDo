from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from enum import Enum

class FriendStatusEnum(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"

class FriendRequestBase(BaseModel):
    user_id: int
    friend_id: int

class FriendRequestCreate(BaseModel):
    friend_id: int  # ID пользователя, которому отправляем заявку

class FriendRequestResponse(BaseModel):
    id: int
    user_id: int
    friend_id: int
    status: FriendStatusEnum
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class FriendResponse(BaseModel):
    id: int
    username: str
    email: str
    
    class Config:
        from_attributes = True

class FriendRequestAction(BaseModel):
    request_id: int
    action: str  # "accept" или "reject"