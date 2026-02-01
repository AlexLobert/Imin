from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.chat import (
    MessageCreate,
    MessageResponse,
    MessagesListResponse,
    ThreadCreate,
    ThreadReadRequest,
    ThreadReadResponse,
    ThreadResponse,
    ThreadsListResponse,
)
from app.schemas.errors import ErrorResponse
from app.services import chat_service


router = APIRouter(tags=["Chat"])


@router.get(
    "/threads",
    response_model=ThreadsListResponse,
    summary="List threads",
    description="List all 1:1 chat threads.",
    operation_id="listThreads",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_threads(request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    rows = chat_service.list_threads(db=db, user_id=user.user_id)
    items = []
    for thread, last_message in rows:
        other_user_id = thread.user_high_id if thread.user_low_id == user.user_id else thread.user_low_id
        preview = None
        if last_message:
            preview = {
                "message_id": last_message.message_id,
                "sender_id": last_message.sender_id,
                "text": last_message.text,
                "created_at": last_message.created_at,
            }
        items.append(
            ThreadResponse(
                thread_id=thread.thread_id,
                other_user_id=other_user_id,
                created_at=thread.created_at,
                last_message=preview,
            )
        )
    return ThreadsListResponse(items=items, next_cursor=None)


@router.post(
    "/threads",
    response_model=ThreadResponse,
    status_code=201,
    summary="Open or create thread",
    description="Open or create a 1:1 chat thread.",
    operation_id="openOrCreateThread",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        403: {"model": ErrorResponse, "description": "Not friends or blocked"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def create_thread(payload: ThreadCreate, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    thread, error = chat_service.open_or_create_thread(
        db=db, user_id=user.user_id, other_user_id=payload.other_user_id
    )
    if error == "not_friends":
        return error_response(status_code=403, code="NOT_FRIENDS", message="not friends")
    if error == "blocked":
        return error_response(status_code=403, code="USER_BLOCKED", message="user blocked")
    if error == "not_allowed":
        return error_response(status_code=400, code="VALIDATION_ERROR", message="invalid request")
    other_user_id = thread.user_high_id if thread.user_low_id == user.user_id else thread.user_low_id
    return ThreadResponse(
        thread_id=thread.thread_id,
        other_user_id=other_user_id,
        created_at=thread.created_at,
        last_message=None,
    )


@router.get(
    "/threads/{id}/messages",
    response_model=MessagesListResponse,
    summary="List messages",
    description="List messages in a thread.",
    operation_id="listMessages",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Thread not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_messages(
    id: int,
    request: Request,
    before: int | None = None,
    limit: int = 50,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    messages, error = chat_service.list_messages(
        db=db, user_id=user.user_id, thread_id=id, before=before, limit=limit
    )
    if error == "not_found":
        return error_response(status_code=404, code="THREAD_NOT_FOUND", message="thread not found")
    items = [
        MessageResponse(
            message_id=message.message_id,
            thread_id=message.thread_id,
            sender_id=message.sender_id,
            text=message.text,
            created_at=message.created_at,
        )
        for message in messages
    ]
    next_cursor = str(items[-1].message_id) if items else None
    return MessagesListResponse(items=items, next_cursor=next_cursor)


@router.post(
    "/threads/{id}/messages",
    response_model=MessageResponse,
    status_code=201,
    summary="Create message",
    description="Send a message in a thread.",
    operation_id="createMessage",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        403: {"model": ErrorResponse, "description": "Not friends or blocked"},
        404: {"model": ErrorResponse, "description": "Thread not found"},
        429: {"model": ErrorResponse, "description": "Rate limited"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def create_message(
    id: int,
    payload: MessageCreate,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    message, error = chat_service.create_message(
        db=db, user_id=user.user_id, thread_id=id, text=payload.text
    )
    if error == "thread_not_found":
        return error_response(status_code=404, code="THREAD_NOT_FOUND", message="thread not found")
    if error == "not_friends":
        return error_response(status_code=403, code="NOT_FRIENDS", message="not friends")
    if error == "blocked":
        return error_response(status_code=403, code="USER_BLOCKED", message="user blocked")
    if error == "too_long":
        return error_response(status_code=400, code="MESSAGE_TOO_LONG", message="message too long")
    if error == "invalid_text":
        return error_response(status_code=400, code="VALIDATION_ERROR", message="message is empty")
    if error == "rate_limited":
        return error_response(status_code=429, code="RATE_LIMITED", message="rate limit exceeded")
    return MessageResponse(
        message_id=message.message_id,
        thread_id=message.thread_id,
        sender_id=message.sender_id,
        text=message.text,
        created_at=message.created_at,
    )


@router.post(
    "/threads/{id}/read",
    response_model=ThreadReadResponse,
    status_code=200,
    summary="Mark thread as read",
    description="Update the last read message for a thread.",
    operation_id="markThreadRead",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def mark_read(
    id: int,
    payload: ThreadReadRequest,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    error = chat_service.mark_read(
        db=db,
        user_id=user.user_id,
        thread_id=id,
        last_read_message_id=payload.last_read_message_id,
    )
    if error == "thread_not_found":
        return error_response(status_code=404, code="THREAD_NOT_FOUND", message="thread not found")
    if error == "message_not_found":
        return error_response(status_code=404, code="NOT_FOUND", message="message not found")
    return ThreadReadResponse(status="ok")
