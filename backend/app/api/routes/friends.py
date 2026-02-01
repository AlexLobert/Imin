from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.errors import ErrorResponse
from app.schemas.friends import (
    BlockCreate,
    BlockResponse,
    BlocksListResponse,
    FriendRequestCreate,
    FriendRequestPatch,
    FriendRequestResponse,
    FriendRequestsListResponse,
    FriendResponse,
    FriendsListResponse,
)
from app.services import friends_service


router = APIRouter(tags=["Friends"])


@router.get(
    "/friends",
    response_model=FriendsListResponse,
    summary="List friends",
    description="List friends with optional search by name or handle.",
    operation_id="listFriends",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_friends(
    request: Request,
    query: str | None = None,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    rows = friends_service.list_friends(db=db, user_id=user.user_id, query_text=query)
    items = [
        FriendResponse(
            user_id=friend.user_id,
            name=friend.name,
            handle=friend.handle,
            no_circles_assigned=friendship.no_circles_assigned,
        )
        for friendship, friend in rows
    ]
    return FriendsListResponse(items=items, next_cursor=None)


@router.get(
    "/friends/unassigned",
    response_model=FriendsListResponse,
    summary="List unassigned friends",
    description="List friends with no circles assigned.",
    operation_id="listUnassignedFriends",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_unassigned_friends(request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    rows = friends_service.list_unassigned_friends(db=db, user_id=user.user_id)
    items = [
        FriendResponse(
            user_id=friend.user_id,
            name=friend.name,
            handle=friend.handle,
            no_circles_assigned=friendship.no_circles_assigned,
        )
        for friendship, friend in rows
    ]
    return FriendsListResponse(items=items, next_cursor=None)


@router.delete(
    "/friends/{friendId}",
    status_code=204,
    summary="Remove friend",
    description="Remove a friend relationship.",
    operation_id="removeFriend",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def remove_friend(friendId: int, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    removed = friends_service.remove_friend(db=db, user_id=user.user_id, friend_id=friendId)
    if not removed:
        return error_response(status_code=404, code="NOT_FOUND", message="friend not found")
    return JSONResponse(status_code=204, content=None)


@router.post(
    "/friend-requests",
    response_model=FriendRequestResponse,
    status_code=201,
    summary="Create friend request",
    description="Send a friend request to a username (handle).",
    operation_id="createFriendRequest",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        403: {"model": ErrorResponse, "description": "Blocked or not allowed"},
        404: {"model": ErrorResponse, "description": "Username not found"},
        409: {"model": ErrorResponse, "description": "Conflict"},
        429: {"model": ErrorResponse, "description": "Rate limited"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def create_friend_request(
    payload: FriendRequestCreate, request: Request, db: OrmSession = Depends(get_db)
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    request_row, error = friends_service.create_friend_request(
        db=db, sender_id=user.user_id, username=payload.username
    )
    if error == "username_not_found":
        return error_response(
            status_code=404,
            code="USERNAME_NOT_FOUND",
            message="username not found",
        )
    if error == "user_blocked":
        return error_response(
            status_code=403,
            code="USER_BLOCKED",
            message="user is blocked",
        )
    if error == "already_friends":
        return error_response(
            status_code=409,
            code="ALREADY_FRIENDS",
            message="already friends",
        )
    if error == "duplicate_request":
        return error_response(
            status_code=409,
            code="FRIEND_REQUEST_ALREADY_EXISTS",
            message="friend request already exists",
        )
    if error in {"pending_limit", "rate_limited"}:
        return error_response(
            status_code=429,
            code="RATE_LIMITED",
            message="rate limit exceeded",
        )
    if error == "friend_request_not_allowed":
        return error_response(
            status_code=403,
            code="FRIEND_REQUEST_NOT_ALLOWED",
            message="friend request not allowed",
        )
    return FriendRequestResponse(
        request_id=request_row.request_id,
        sender_id=request_row.sender_id,
        recipient_id=request_row.recipient_id,
        status=request_row.status,
        direction="outgoing",
        created_at=request_row.created_at,
    )


@router.get(
    "/friend-requests",
    response_model=FriendRequestsListResponse,
    summary="List friend requests",
    description="List incoming and outgoing friend requests.",
    operation_id="listFriendRequests",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_friend_requests(
    request: Request,
    type: str | None = None,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    requests = friends_service.list_friend_requests(db=db, user_id=user.user_id, request_type=type)
    items = []
    for req in requests:
        direction = "incoming" if req.recipient_id == user.user_id else "outgoing"
        items.append(
            FriendRequestResponse(
                request_id=req.request_id,
                sender_id=req.sender_id,
                recipient_id=req.recipient_id,
                status=req.status,
                direction=direction,
                created_at=req.created_at,
            )
        )
    return FriendRequestsListResponse(items=items, next_cursor=None)


@router.patch(
    "/friend-requests/{id}",
    response_model=FriendRequestResponse,
    summary="Update friend request",
    description="Accept, decline, or cancel a friend request.",
    operation_id="updateFriendRequest",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        403: {"model": ErrorResponse, "description": "Not allowed"},
        404: {"model": ErrorResponse, "description": "Not found"},
        409: {"model": ErrorResponse, "description": "Not pending"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def update_friend_request(
    id: int,
    payload: FriendRequestPatch,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    updated, error = friends_service.update_friend_request(
        db=db,
        user_id=user.user_id,
        request_id=id,
        status=payload.status,
    )
    if error == "not_found":
        return error_response(status_code=404, code="NOT_FOUND", message="request not found")
    if error == "not_pending":
        return error_response(
            status_code=409,
            code="FRIEND_REQUEST_NOT_PENDING",
            message="friend request not pending",
        )
    if error == "not_allowed":
        return error_response(
            status_code=403,
            code="FRIEND_REQUEST_NOT_ALLOWED",
            message="friend request not allowed",
        )
    return FriendRequestResponse(
        request_id=updated.request_id,
        sender_id=updated.sender_id,
        recipient_id=updated.recipient_id,
        status=updated.status,
        direction="incoming" if updated.recipient_id == user.user_id else "outgoing",
        created_at=updated.created_at,
    )


@router.post(
    "/blocks",
    response_model=BlockResponse,
    status_code=201,
    summary="Block a user",
    description="Block a user by user id.",
    operation_id="blockUser",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        400: {"model": ErrorResponse, "description": "Invalid request"},
        409: {"model": ErrorResponse, "description": "Already blocked"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def block_user(payload: BlockCreate, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    block, error = friends_service.create_block(
        db=db,
        blocker_id=user.user_id,
        blocked_id=payload.user_id,
    )
    if error == "block_exists":
        return error_response(
            status_code=409,
            code="BLOCK_ALREADY_EXISTS",
            message="block already exists",
        )
    if error == "not_allowed":
        return error_response(
            status_code=400,
            code="VALIDATION_ERROR",
            message="cannot block this user",
        )
    return BlockResponse(user_id=block.blocked_id, created_at=block.created_at)


@router.delete(
    "/blocks/{userId}",
    status_code=204,
    summary="Unblock a user",
    description="Remove a block for a user id.",
    operation_id="unblockUser",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def unblock_user(userId: int, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    removed = friends_service.delete_block(db=db, blocker_id=user.user_id, blocked_id=userId)
    if not removed:
        return error_response(status_code=404, code="NOT_FOUND", message="block not found")
    return JSONResponse(status_code=204, content=None)


@router.get(
    "/blocks",
    response_model=BlocksListResponse,
    summary="List blocked users",
    description="List users blocked by the current user.",
    operation_id="listBlocks",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_blocks(request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    blocks = friends_service.list_blocks(db=db, blocker_id=user.user_id)
    items = [BlockResponse(user_id=block.blocked_id, created_at=block.created_at) for block in blocks]
    return BlocksListResponse(items=items, next_cursor=None)
