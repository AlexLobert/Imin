from datetime import datetime

from pydantic import BaseModel


class MessageResponse(BaseModel):
    message_id: int
    thread_id: int
    sender_id: int
    text: str
    created_at: datetime


class MessagePreview(BaseModel):
    message_id: int
    sender_id: int
    text: str
    created_at: datetime


class ThreadResponse(BaseModel):
    thread_id: int
    other_user_id: int
    created_at: datetime
    last_message: MessagePreview | None = None


class ThreadsListResponse(BaseModel):
    items: list[ThreadResponse]
    next_cursor: str | None = None


class MessagesListResponse(BaseModel):
    items: list[MessageResponse]
    next_cursor: str | None = None


class ThreadCreate(BaseModel):
    other_user_id: int


class MessageCreate(BaseModel):
    text: str


class ThreadReadRequest(BaseModel):
    last_read_message_id: int


class ThreadReadResponse(BaseModel):
    status: str
