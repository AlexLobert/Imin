from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session as OrmSession

from app.models.block import Block
from app.models.circle import Circle
from app.models.circle_member import CircleMember
from app.models.friend_request import FriendRequest
from app.models.friendship import Friendship
from app.models.user import User
from app.services.circles_service import ensure_everyone_circle
from app.services.rate_limit_service import check_rate_limit
from app.services.relationship_service import are_friends, is_blocked


def get_user_by_handle(db: OrmSession, handle: str) -> User | None:
    normalized = handle.strip().lower()
    if not normalized:
        return None
    return db.scalar(select(User).where(func.lower(User.handle) == normalized))


def create_friend_request(
    db: OrmSession, sender_id: int, username: str
) -> tuple[FriendRequest | None, str | None]:
    recipient = get_user_by_handle(db, username)
    if not recipient:
        return None, "username_not_found"
    if recipient.user_id == sender_id:
        return None, "friend_request_not_allowed"
    if is_blocked(db, sender_id, recipient.user_id):
        return None, "user_blocked"
    if are_friends(db, sender_id, recipient.user_id):
        return None, "already_friends"
    pending_outgoing = db.scalar(
        select(func.count())
        .select_from(FriendRequest)
        .where(
            FriendRequest.sender_id == sender_id,
            FriendRequest.status == "pending",
        )
    )
    if pending_outgoing is not None and pending_outgoing >= 50:
        return None, "pending_limit"
    exists = db.scalar(
        select(FriendRequest).where(
            FriendRequest.status == "pending",
            or_(
                (FriendRequest.sender_id == sender_id)
                & (FriendRequest.recipient_id == recipient.user_id),
                (FriendRequest.sender_id == recipient.user_id)
                & (FriendRequest.recipient_id == sender_id),
            ),
        )
    )
    if exists:
        return None, "duplicate_request"
    if not check_rate_limit(db, sender_id, "friend_requests_daily", 20, 86400):
        return None, "rate_limited"
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    request = FriendRequest(
        sender_id=sender_id,
        recipient_id=recipient.user_id,
        status="pending",
        created_at=now,
        updated_at=now,
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request, None


def list_friend_requests(
    db: OrmSession, user_id: int, request_type: str | None
) -> list[FriendRequest]:
    query = select(FriendRequest)
    if request_type == "incoming":
        query = query.where(FriendRequest.recipient_id == user_id)
    elif request_type == "outgoing":
        query = query.where(FriendRequest.sender_id == user_id)
    else:
        query = query.where(
            or_(
                FriendRequest.sender_id == user_id,
                FriendRequest.recipient_id == user_id,
            )
        )
    return db.scalars(query.order_by(FriendRequest.created_at.desc())).all()


def update_friend_request(
    db: OrmSession, user_id: int, request_id: int, status: str
) -> tuple[FriendRequest | None, str | None]:
    request = db.scalar(select(FriendRequest).where(FriendRequest.request_id == request_id))
    if not request:
        return None, "not_found"
    if request.status != "pending":
        return None, "not_pending"
    if status == "accepted":
        if request.recipient_id != user_id:
            return None, "not_allowed"
        if is_blocked(db, request.sender_id, request.recipient_id):
            return None, "not_allowed"
        _create_friendship_pair(db, request.sender_id, request.recipient_id)
    elif status == "declined":
        if request.recipient_id != user_id:
            return None, "not_allowed"
    elif status == "canceled":
        if request.sender_id != user_id:
            return None, "not_allowed"
    else:
        return None, "invalid_status"
    request.status = status
    request.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(request)
    return request, None


def list_friends(db: OrmSession, user_id: int, query_text: str | None) -> list[tuple[Friendship, User]]:
    query = (
        select(Friendship, User)
        .join(User, Friendship.friend_id == User.user_id)
        .where(Friendship.user_id == user_id)
    )
    if query_text:
        needle = f"%{query_text.strip().lower()}%"
        query = query.where(
            or_(
                func.lower(User.handle).like(needle),
                func.lower(User.name).like(needle),
            )
        )
    return db.execute(query.order_by(User.handle.asc())).all()


def list_unassigned_friends(db: OrmSession, user_id: int) -> list[tuple[Friendship, User]]:
    query = (
        select(Friendship, User)
        .join(User, Friendship.friend_id == User.user_id)
        .where(
            Friendship.user_id == user_id,
            Friendship.no_circles_assigned.is_(True),
        )
    )
    return db.execute(query.order_by(User.handle.asc())).all()


def remove_friend(db: OrmSession, user_id: int, friend_id: int) -> bool:
    removed = (
        db.query(Friendship)
        .filter(Friendship.user_id == user_id, Friendship.friend_id == friend_id)
        .delete()
    )
    db.query(Friendship).filter(
        Friendship.user_id == friend_id, Friendship.friend_id == user_id
    ).delete()
    _remove_circle_memberships(db, user_id, friend_id)
    _remove_circle_memberships(db, friend_id, user_id)
    db.commit()
    return removed > 0


def create_block(db: OrmSession, blocker_id: int, blocked_id: int) -> tuple[Block | None, str | None]:
    if blocker_id == blocked_id:
        return None, "not_allowed"
    existing = db.scalar(
        select(Block).where(Block.blocker_id == blocker_id, Block.blocked_id == blocked_id)
    )
    if existing:
        return None, "block_exists"
    block = Block(blocker_id=blocker_id, blocked_id=blocked_id)
    db.add(block)
    _remove_friendship_pair(db, blocker_id, blocked_id)
    _cancel_pending_requests(db, blocker_id, blocked_id)
    db.commit()
    db.refresh(block)
    return block, None


def delete_block(db: OrmSession, blocker_id: int, blocked_id: int) -> bool:
    removed = (
        db.query(Block)
        .filter(Block.blocker_id == blocker_id, Block.blocked_id == blocked_id)
        .delete()
    )
    db.commit()
    return removed > 0


def list_blocks(db: OrmSession, blocker_id: int) -> list[Block]:
    return db.scalars(select(Block).where(Block.blocker_id == blocker_id)).all()


def _create_friendship_pair(db: OrmSession, user_id: int, friend_id: int) -> None:
    for owner_id, other_id in ((user_id, friend_id), (friend_id, user_id)):
        existing = db.scalar(
            select(Friendship).where(
                Friendship.user_id == owner_id,
                Friendship.friend_id == other_id,
            )
        )
        if existing:
            continue
        friendship = Friendship(user_id=owner_id, friend_id=other_id, no_circles_assigned=False)
        db.add(friendship)
    db.commit()
    for owner_id, other_id in ((user_id, friend_id), (friend_id, user_id)):
        circle = ensure_everyone_circle(db, owner_id)
        membership = db.scalar(
            select(CircleMember).where(
                CircleMember.circle_id == circle.circle_id,
                CircleMember.member_user_id == other_id,
            )
        )
        if not membership:
            db.add(CircleMember(circle_id=circle.circle_id, member_user_id=other_id))
    db.commit()


def _remove_friendship_pair(db: OrmSession, user_id: int, friend_id: int) -> None:
    db.query(Friendship).filter(
        Friendship.user_id == user_id, Friendship.friend_id == friend_id
    ).delete()
    db.query(Friendship).filter(
        Friendship.user_id == friend_id, Friendship.friend_id == user_id
    ).delete()
    _remove_circle_memberships(db, user_id, friend_id)
    _remove_circle_memberships(db, friend_id, user_id)


def _remove_circle_memberships(db: OrmSession, owner_id: int, member_id: int) -> None:
    circle_ids = db.scalars(select(Circle.circle_id).where(Circle.owner_id == owner_id)).all()
    if not circle_ids:
        return
    db.query(CircleMember).filter(
        CircleMember.member_user_id == member_id,
        CircleMember.circle_id.in_(circle_ids),
    ).delete()


def _cancel_pending_requests(db: OrmSession, user_id: int, other_id: int) -> None:
    requests = db.scalars(
        select(FriendRequest).where(
            FriendRequest.status == "pending",
            or_(
                (FriendRequest.sender_id == user_id)
                & (FriendRequest.recipient_id == other_id),
                (FriendRequest.sender_id == other_id)
                & (FriendRequest.recipient_id == user_id),
            ),
        )
    ).all()
    if not requests:
        return
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    for request in requests:
        request.status = "canceled"
        request.updated_at = now
    db.commit()
