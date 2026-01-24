from typing import Any

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


def error_payload(code: str, message: str, details: Any | None = None) -> dict:
    payload = {"error": {"code": code, "message": message}}
    if details is not None:
        payload["error"]["details"] = details
    return payload


def error_response(
    status_code: int,
    code: str,
    message: str,
    details: Any | None = None,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=error_payload(code=code, message=message, details=details),
    )


def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    return error_response(
        status_code=422,
        code="VALIDATION_ERROR",
        message="Validation error",
        details={"errors": exc.errors()},
    )


def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    details: Any | None = None
    if isinstance(exc.detail, str):
        message = exc.detail
    else:
        message = "Request failed"
        details = exc.detail
    return error_response(
        status_code=exc.status_code,
        code="HTTP_ERROR",
        message=message,
        details=details,
    )


def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return error_response(
        status_code=500,
        code="INTERNAL_ERROR",
        message="Internal server error",
    )
