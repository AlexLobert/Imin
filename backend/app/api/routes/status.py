from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.auth.session import get_user_for_session
from app.config import settings
from app.db.database import get_db
from app.schemas.status import StatusRequest
from app.services.status_service import set_status as set_status_service


router = APIRouter()


def _error(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"ok": False, "error": message})


@router.post("/set_status")
def set_status(
    payload: StatusRequest,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    session_id = request.cookies.get(settings.SESSION_COOKIE_NAME)
    user = get_user_for_session(db=db, session_id=session_id)
    if not user:
        return _error(401, "auth required")
    if payload.status not in {"In", "Out"}:
        return _error(400, "status must be 'In' or 'Out'")
    status_value = set_status_service(db=db, user=user, status=payload.status)
    return JSONResponse(status_code=200, content={"ok": True, "status": status_value})
