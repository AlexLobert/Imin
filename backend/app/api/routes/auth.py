from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.config import settings
from app.db.database import get_db
from app.schemas.auth import CreateAccountRequest, LoginRequest
from app.services import auth_service


router = APIRouter()


def _error(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"ok": False, "error": message})


@router.post("/create_account")
def create_account(payload: CreateAccountRequest, db: OrmSession = Depends(get_db)):
    user, error = auth_service.create_account(
        db=db,
        email=payload.email,
        password=payload.password,
        first_name=payload.first_name,
        last_name=payload.last_name,
    )
    if error == "duplicate_email":
        return _error(409, "this email address is already associated with an account")
    if error:
        return _error(400, error)
    return JSONResponse(status_code=201, content={"ok": True, "user_id": user.user_id})


@router.post("/login")
def login(payload: LoginRequest, db: OrmSession = Depends(get_db)):
    session_id = auth_service.login(db=db, email=payload.email, password=payload.password)
    if not session_id:
        return _error(401, "info wrong. me no open")
    response = JSONResponse(status_code=200, content={"ok": True})
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=session_id,
        httponly=True,
        samesite="lax",
        secure=settings.SESSION_COOKIE_SECURE,
        max_age=settings.SESSION_TTL_DAYS * 24 * 60 * 60,
    )
    return response


@router.post("/logout")
def logout(request: Request, db: OrmSession = Depends(get_db)):
    session_id = request.cookies.get(settings.SESSION_COOKIE_NAME)
    auth_service.logout(db=db, session_id=session_id)
    response = JSONResponse(status_code=200, content={"ok": True})
    response.delete_cookie(key=settings.SESSION_COOKIE_NAME)
    return response
