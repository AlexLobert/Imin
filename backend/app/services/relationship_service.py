from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.models.block import Block
from app.models.friendship import Friendship


def are_friends(db: OrmSession, user_id: int, other_user_id: int) -> bool:
    friendship = db.scalar(
        select(Friendship).where(
            Friendship.user_id == user_id,
            Friendship.friend_id == other_user_id,
        )
    )
    return friendship is not None


def is_blocked(db: OrmSession, user_id: int, other_user_id: int) -> bool:
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
