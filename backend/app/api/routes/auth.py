from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_user_for_session
from app.config import settings
from app.db.database import get_db
from app.schemas.auth import (
    CreateAccountRequest,
    CreateAccountResponse,
    LoginRequest,
    LoginResponse,
    LogoutResponse,
)
from app.schemas.errors import ErrorResponse
from app.services import auth_service


router = APIRouter(tags=["Auth"])


@router.post(
    "/create_account",
    response_model=CreateAccountResponse,
    status_code=201,
    responses={
        400: {"model": ErrorResponse, "description": "Password does not meet requirements"},
        409: {"model": ErrorResponse, "description": "Email already in use"},
        422: {"model": ErrorResponse, "description": "Validation error (standardized)"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def create_account(payload: CreateAccountRequest, db: OrmSession = Depends(get_db)):
    user, error = auth_service.create_account(
        db=db,
        email=payload.email,
        password=payload.password,
        first_name=None,
        last_name=None,
    )
    if error == "duplicate_email":
        return error_response(
            status_code=409,
            code="EMAIL_IN_USE",
            message="this email address is already associated with an account",
        )
    if error:
        return error_response(status_code=400, code="PASSWORD_INVALID", message=error)
    return CreateAccountResponse(
        user_id=str(user.user_id),
        email=user.email,
        message="account created",
    )


@router.post(
    "/login",
    response_model=LoginResponse,
    responses={
        401: {
            "model": ErrorResponse,
            "description": "Invalid credentials",
        },
        422: {"model": ErrorResponse, "description": "Validation error (standardized)"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def login(payload: LoginRequest, db: OrmSession = Depends(get_db)):
    session_id = auth_service.login(db=db, email=payload.email, password=payload.password)
    if not session_id:
        return error_response(
            status_code=401,
            code="INVALID_CREDENTIALS",
            message="info wrong. me no open",
        )
    response = JSONResponse(
        status_code=200,
        content={"access_token": session_id, "token_type": "bearer"},
    )
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=session_id,
        httponly=True,
        samesite="lax",
        secure=settings.SESSION_COOKIE_SECURE,
        max_age=settings.SESSION_TTL_DAYS * 24 * 60 * 60,
    )
    return response


@router.post(
    "/logout",
    response_model=LogoutResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def logout(request: Request, db: OrmSession = Depends(get_db)):
    session_id = request.cookies.get(settings.SESSION_COOKIE_NAME)
    if not session_id or not get_user_for_session(db=db, session_id=session_id):
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    auth_service.logout(db=db, session_id=session_id)
    response = JSONResponse(status_code=200, content={"message": "logged out"})
    response.delete_cookie(key=settings.SESSION_COOKIE_NAME)
    return response
