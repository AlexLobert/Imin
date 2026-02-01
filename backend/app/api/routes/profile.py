from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.errors import ErrorResponse
from app.schemas.profile import HandleAvailableResponse, MePatchRequest, MeResponse
from app.services import profile_service


router = APIRouter(tags=["Profile"])

_HANDLE_LIMITS: dict[str, tuple[datetime, int]] = {}


def _check_handle_rate_limit(key: str) -> bool:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    entry = _HANDLE_LIMITS.get(key)
    if not entry:
        _HANDLE_LIMITS[key] = (now, 1)
        return True
    window_start, count = entry
    if (now - window_start).total_seconds() >= 60:
        _HANDLE_LIMITS[key] = (now, 1)
        return True
    if count >= 60:
        return False
    _HANDLE_LIMITS[key] = (window_start, count + 1)
    return True


@router.get(
    "/me",
    response_model=MeResponse,
    summary="Get current profile",
    description="Fetch the current user's profile.",
    operation_id="getMe",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def get_me(request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    return MeResponse(
        user_id=user.user_id,
        email=user.email,
        name=user.name,
        handle=user.handle,
        created_at=user.created_at,
    )


@router.patch(
    "/me",
    response_model=MeResponse,
    summary="Update current profile",
    description="Update the current user's profile name or handle.",
    operation_id="patchMe",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        409: {"model": ErrorResponse, "description": "Handle not available"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def patch_me(
    payload: MePatchRequest,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    updated, error = profile_service.update_profile(
        db=db,
        user=user,
        name=payload.name,
        handle=payload.handle,
    )
    if error == "handle_taken":
        return error_response(
            status_code=409,
            code="HANDLE_NOT_AVAILABLE",
            message="handle is not available",
        )
    if error == "invalid_handle":
        return error_response(
            status_code=400,
            code="HANDLE_NOT_AVAILABLE",
            message="handle is invalid",
        )
    return MeResponse(
        user_id=updated.user_id,
        email=updated.email,
        name=updated.name,
        handle=updated.handle,
        created_at=updated.created_at,
    )


@router.get(
    "/handles/{handle}/available",
    response_model=HandleAvailableResponse,
    summary="Check handle availability",
    description="Check if a handle is available for use.",
    operation_id="handleAvailable",
    responses={
        429: {"model": ErrorResponse, "description": "Rate limited"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def handle_available(
    handle: str,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    client_host = request.client.host if request.client else "unknown"
    key = f"user:{user.user_id}" if user else f"ip:{client_host}"
    if not _check_handle_rate_limit(key):
        return error_response(
            status_code=429,
            code="RATE_LIMITED",
            message="rate limit exceeded",
        )
    available = profile_service.is_handle_available(
        db=db,
        handle=handle,
        current_user_id=user.user_id if user else None,
    )
    return HandleAvailableResponse(available=available)
