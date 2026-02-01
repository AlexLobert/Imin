from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class FriendResponse(BaseModel):
    user_id: int
    name: str | None
    handle: str | None
    no_circles_assigned: bool


class FriendsListResponse(BaseModel):
    items: list[FriendResponse]
    next_cursor: str | None = None


class FriendRequestCreate(BaseModel):
    username: str


class FriendRequestResponse(BaseModel):
    request_id: int
    sender_id: int
    recipient_id: int
    status: str
    direction: Literal["incoming", "outgoing"] | None = None
    created_at: datetime


class FriendRequestsListResponse(BaseModel):
    items: list[FriendRequestResponse]
    next_cursor: str | None = None


class FriendRequestPatch(BaseModel):
    status: Literal["accepted", "declined", "canceled"]


class BlockCreate(BaseModel):
    user_id: int


class BlockResponse(BaseModel):
    user_id: int
    created_at: datetime


class BlocksListResponse(BaseModel):
    items: list[BlockResponse]
    next_cursor: str | None = None
