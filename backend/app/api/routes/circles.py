from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.circles import (
    CircleCreate,
    CircleMembersAddedResponse,
    CircleMembersBatchAdd,
    CirclePatch,
    CircleResponse,
    CirclesListResponse,
)
from app.schemas.errors import ErrorResponse
from app.services import circles_service


router = APIRouter(tags=["Circles"])


@router.get(
    "/circles",
    response_model=CirclesListResponse,
    summary="List circles",
    description="List all circles for the current user.",
    operation_id="listCircles",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_circles(request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    circles = circles_service.list_circles(db=db, owner_id=user.user_id)
    items = [
        CircleResponse(circle_id=c.circle_id, name=c.name, is_system=c.is_system)
        for c in circles
    ]
    return CirclesListResponse(items=items, next_cursor=None)


@router.post(
    "/circles",
    response_model=CircleResponse,
    status_code=201,
    summary="Create circle",
    description="Create a new circle for organizing friends.",
    operation_id="createCircle",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        409: {"model": ErrorResponse, "description": "Conflict"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def create_circle(payload: CircleCreate, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    circle, error = circles_service.create_circle(db=db, owner_id=user.user_id, name=payload.name)
    if error == "circle_limit_reached":
        return error_response(
            status_code=409,
            code="CIRCLE_LIMIT_REACHED",
            message="circle limit reached",
        )
    if error == "name_taken":
        return error_response(
            status_code=409,
            code="CIRCLE_NAME_TAKEN",
            message="circle name already in use",
        )
    if error == "invalid_name":
        return error_response(
            status_code=400,
            code="VALIDATION_ERROR",
            message="circle name is invalid",
        )
    return CircleResponse(circle_id=circle.circle_id, name=circle.name, is_system=circle.is_system)


@router.patch(
    "/circles/{id}",
    response_model=CircleResponse,
    summary="Update circle",
    description="Update a circle name.",
    operation_id="updateCircle",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        409: {"model": ErrorResponse, "description": "Conflict"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def update_circle(
    id: int, payload: CirclePatch, request: Request, db: OrmSession = Depends(get_db)
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    circle, error = circles_service.update_circle(
        db=db, owner_id=user.user_id, circle_id=id, name=payload.name
    )
    if error == "not_found":
        return error_response(status_code=404, code="CIRCLE_NOT_FOUND", message="circle not found")
    if error == "system_immutable":
        return error_response(
            status_code=409,
            code="CIRCLE_SYSTEM_IMMUTABLE",
            message="circle is system and cannot be changed",
        )
    if error == "name_taken":
        return error_response(
            status_code=409,
            code="CIRCLE_NAME_TAKEN",
            message="circle name already in use",
        )
    if error == "invalid_name":
        return error_response(
            status_code=400,
            code="VALIDATION_ERROR",
            message="circle name is invalid",
        )
    return CircleResponse(circle_id=circle.circle_id, name=circle.name, is_system=circle.is_system)


@router.delete(
    "/circles/{id}",
    status_code=204,
    summary="Delete circle",
    description="Delete a circle.",
    operation_id="deleteCircle",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        409: {"model": ErrorResponse, "description": "Conflict"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def delete_circle(id: int, request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    error = circles_service.delete_circle(db=db, owner_id=user.user_id, circle_id=id)
    if error == "not_found":
        return error_response(status_code=404, code="CIRCLE_NOT_FOUND", message="circle not found")
    if error == "system_immutable":
        return error_response(
            status_code=409,
            code="CIRCLE_SYSTEM_IMMUTABLE",
            message="circle is system and cannot be deleted",
        )
    return JSONResponse(status_code=204, content=None)


@router.post(
    "/circles/{id}/members",
    response_model=CircleMembersAddedResponse,
    summary="Add circle members",
    description="Batch add members to a circle (max 100).",
    operation_id="addCircleMembers",
    responses={
        200: {"model": CircleMembersAddedResponse, "description": "Members added"},
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        409: {"model": ErrorResponse, "description": "Conflict"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def add_members(
    id: int,
    payload: CircleMembersBatchAdd,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    added, error = circles_service.add_members_batch(
        db=db, owner_id=user.user_id, circle_id=id, member_ids=payload.member_ids
    )
    if error == "not_found":
        return error_response(status_code=404, code="CIRCLE_NOT_FOUND", message="circle not found")
    if error == "batch_limit":
        return error_response(
            status_code=400,
            code="BATCH_LIMIT_EXCEEDED",
            message="batch limit exceeded",
        )
    if error == "member_limit":
        return error_response(
            status_code=409,
            code="CIRCLE_MEMBER_LIMIT_REACHED",
            message="circle member limit reached",
        )
    if error == "member_not_friend":
        return error_response(
            status_code=409,
            code="CIRCLE_MEMBER_NOT_FRIEND",
            message="circle members must be friends",
        )
    return {"added": added}


@router.delete(
    "/circles/{id}/members/{memberId}",
    status_code=204,
    summary="Remove circle member",
    description="Remove a member from a circle.",
    operation_id="removeCircleMember",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def remove_member(
    id: int,
    memberId: int,
    request: Request,
    db: OrmSession = Depends(get_db),
):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    error = circles_service.remove_member(
        db=db, owner_id=user.user_id, circle_id=id, member_id=memberId
    )
    if error in {"not_found", "membership_not_found"}:
        return error_response(status_code=404, code="CIRCLE_NOT_FOUND", message="circle member not found")
    return JSONResponse(status_code=204, content=None)
