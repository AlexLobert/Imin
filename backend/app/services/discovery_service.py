from sqlalchemy import func, select
from sqlalchemy.orm import Session as OrmSession

from app.models.block import Block
from app.models.circle import Circle
from app.models.circle_member import CircleMember
from app.models.friendship import Friendship
from app.models.user import User


def list_in_now(db: OrmSession, user_id: int) -> list[User]:
    friendships = db.scalars(
        select(Friendship).where(Friendship.user_id == user_id)
    ).all()
    friend_ids = [friendship.friend_id for friendship in friendships]
    if not friend_ids:
        return []
    friends = db.scalars(select(User).where(User.user_id.in_(friend_ids))).all()
    visible_friends: list[User] = []
    for friend in friends:
        if friend.status != "In":
            continue
        if _is_blocked(db, user_id, friend.user_id):
            continue
        visible_ids = friend.status_visible_circle_ids or []
        if not visible_ids:
            continue
        visible = db.scalar(
            select(func.count())
            .select_from(CircleMember)
            .join(Circle, Circle.circle_id == CircleMember.circle_id)
            .where(
                Circle.owner_id == friend.user_id,
                Circle.circle_id.in_(visible_ids),
                CircleMember.member_user_id == user_id,
            )
        )
        if visible:
            visible_friends.append(friend)
    return visible_friends


def _is_blocked(db: OrmSession, user_id: int, other_user_id: int) -> bool:
    block = db.scalar(
        select(Block).where(
            (Block.blocker_id == user_id) & (Block.blocked_id == other_user_id)
        )
    )
    if block:
        return True
    reverse = db.scalar(
        select(Block).where(
            (Block.blocker_id == other_user_id) & (Block.blocked_id == user_id)
        )
    )
    return reverse is not None
