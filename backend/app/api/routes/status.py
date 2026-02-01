from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_user_for_session
from app.config import settings
from app.db.database import get_db
from app.schemas.errors import ErrorResponse
from app.schemas.status import SetStatusResponse, StatusRequest
from app.services.status_service import set_status as set_status_service


router = APIRouter(tags=["Status"])


@router.post(
    "/set_status",
    response_model=SetStatusResponse,
    summary="Set current status",
    description="Update current user's status and visibility circles.",
    operation_id="setStatus",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid status"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Circle not found"},
        422: {"model": ErrorResponse, "description": "Validation error (standardized)"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def set_status(
    payload: StatusRequest,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    session_id = request.cookies.get(settings.SESSION_COOKIE_NAME)
    user = get_user_for_session(db=db, session_id=session_id)
    if not user:
        return error_response(
            status_code=401,
            code="UNAUTHORIZED",
            message="auth required",
        )
    if payload.status not in {"In", "Out"}:
        return error_response(
            status_code=400,
            code="STATUS_INVALID",
            message="status must be 'In' or 'Out'",
        )
    updated_user, error = set_status_service(
        db=db,
        user=user,
        status=payload.status,
        visible_circle_ids=payload.visible_circle_ids,
    )
    if error == "circle_not_found":
        return error_response(
            status_code=404,
            code="CIRCLE_NOT_FOUND",
            message="circle not found",
        )
    return JSONResponse(
        status_code=200,
        content={
            "status": updated_user.status,
            "visible_circle_ids": updated_user.status_visible_circle_ids,
            "message": "status updated",
        },
    )
