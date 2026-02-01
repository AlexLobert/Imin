from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.devices import DeviceCreate, DeviceResponse
from app.schemas.errors import ErrorResponse
from app.services import devices_service


router = APIRouter(tags=["Devices"])


@router.post(
    "/devices",
    response_model=DeviceResponse,
    status_code=201,
    summary="Register device",
    description="Register or update a device token.",
    operation_id="registerDevice",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid token"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def register_device(
    payload: DeviceCreate, request: Request, db: OrmSession = Depends(get_db)
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    device, error = devices_service.register_device(
        db=db,
        user_id=user.user_id,
        platform=payload.platform,
        token=payload.token,
        device_identifier=payload.device_id,
    )
    if error == "invalid":
        return error_response(
            status_code=400,
            code="DEVICE_TOKEN_INVALID",
            message="device token invalid",
        )
    return DeviceResponse(
        device_id=device.device_id,
        platform=device.platform,
        token=device.token,
        device_identifier=device.device_identifier,
    )


@router.delete(
    "/devices/{id}",
    status_code=204,
    summary="Delete device",
    description="Delete a device token.",
    operation_id="deleteDevice",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def delete_device(id: int, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    removed = devices_service.delete_device(db=db, user_id=user.user_id, device_id=id)
    if not removed:
        return error_response(status_code=404, code="NOT_FOUND", message="device not found")
    return JSONResponse(status_code=204, content=None)
