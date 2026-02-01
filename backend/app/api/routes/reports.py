from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.errors import ErrorResponse
from app.schemas.reports import ReportCreate, ReportResponse
from app.services import reports_service


router = APIRouter(tags=["Safety"])


@router.post(
    "/reports",
    response_model=ReportResponse,
    status_code=201,
    summary="Report user",
    description="Report a user for safety review.",
    operation_id="createReport",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        429: {"model": ErrorResponse, "description": "Rate limited"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def create_report(payload: ReportCreate, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    report, error = reports_service.create_report(
        db=db,
        reporter_user_id=user.user_id,
        target_user_id=payload.target_user_id,
        reason=payload.reason,
        details=payload.details,
    )
    if error == "rate_limited":
        return error_response(
            status_code=429,
            code="REPORT_LIMIT_REACHED",
            message="report limit reached",
        )
    if error == "invalid_reason":
        return error_response(
            status_code=400,
            code="VALIDATION_ERROR",
            message="reason is required",
        )
    return ReportResponse(
        report_id=report.report_id,
        target_user_id=report.target_user_id,
        reason=report.reason,
        details=report.details,
        status=report.status,
        created_at=report.created_at,
    )
