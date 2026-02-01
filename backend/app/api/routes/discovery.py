from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session as OrmSession

from app.api.errors import error_response
from app.auth.session import get_current_user
from app.db.database import get_db
from app.schemas.errors import ErrorResponse
from app.schemas.friends import FriendResponse, FriendsListResponse
from app.services import discovery_service


router = APIRouter(tags=["Discovery"])


@router.get(
    "/in_now",
    response_model=FriendsListResponse,
    summary="List friends who are In",
    description="List friends who are currently In and visible to the viewer.",
    operation_id="listInNow",
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
def list_in_now(request: Request, db: OrmSession = Depends(get_db)):
    user = get_current_user(db=db, request=request)
    if not user:
        return error_response(status_code=401, code="UNAUTHORIZED", message="unauthorized")
    friends = discovery_service.list_in_now(db=db, user_id=user.user_id)
    items = [
        FriendResponse(
            user_id=friend.user_id,
            name=friend.name,
            handle=friend.handle,
            no_circles_assigned=False,
        )
        for friend in friends
    ]
    return FriendsListResponse(items=items, next_cursor=None)
