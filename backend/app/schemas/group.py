from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List
from enum import Enum

class GroupRoleEnum(str, Enum):
    ADMIN = "admin"
    MEMBER = "member"

class GroupBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None

class GroupCreate(GroupBase):
    pass

class GroupUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None

class GroupResponse(GroupBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class GroupMemberResponse(BaseModel):
    id: int
    user_id: int
    username: str
    email: str
    role: GroupRoleEnum
    joined_at: datetime
    
    class Config:
        from_attributes = True

class GroupDetailResponse(GroupResponse):
    members: List[GroupMemberResponse]

class GroupInviteCreate(BaseModel):
    user_id: int  # ID пользователя, которого приглашаем в группу

class GroupInviteResponse(BaseModel):
    group_id: int
    group_name: str
    inviter_id: int
    inviter_name: str
    invited_user_id: int
    status: str