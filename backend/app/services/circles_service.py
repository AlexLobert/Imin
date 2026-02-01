from sqlalchemy import func, select
from sqlalchemy.orm import Session as OrmSession

from app.models.circle import Circle
from app.models.circle_member import CircleMember
from app.models.friendship import Friendship
from app.services.relationship_service import are_friends


EVERYONE_CIRCLE_NAME = "Everyone"


def ensure_everyone_circle(db: OrmSession, owner_id: int) -> Circle:
    existing = db.scalar(
        select(Circle).where(
            Circle.owner_id == owner_id,
            Circle.name == EVERYONE_CIRCLE_NAME,
        )
    )
    if existing:
        if not existing.is_system:
            existing.is_system = True
            db.commit()
            db.refresh(existing)
        return existing
    circle = Circle(
        owner_id=owner_id,
        name=EVERYONE_CIRCLE_NAME,
        is_system=True,
    )
    db.add(circle)
    db.commit()
    db.refresh(circle)
    return circle


def list_circles(db: OrmSession, owner_id: int) -> list[Circle]:
    ensure_everyone_circle(db, owner_id)
    return db.scalars(select(Circle).where(Circle.owner_id == owner_id)).all()


def create_circle(db: OrmSession, owner_id: int, name: str) -> tuple[Circle | None, str | None]:
    existing_count = db.scalar(
        select(func.count()).select_from(Circle).where(Circle.owner_id == owner_id)
    )
    if existing_count is not None and existing_count >= 25:
        return None, "circle_limit_reached"
    name = name.strip()
    if not name:
        return None, "invalid_name"
    existing = db.scalar(
        select(Circle).where(Circle.owner_id == owner_id, Circle.name == name)
    )
    if existing:
        return None, "name_taken"
    circle = Circle(owner_id=owner_id, name=name, is_system=False)
    db.add(circle)
    db.commit()
    db.refresh(circle)
    return circle, None


def update_circle(
    db: OrmSession, owner_id: int, circle_id: int, name: str
) -> tuple[Circle | None, str | None]:
    circle = db.scalar(
        select(Circle).where(Circle.owner_id == owner_id, Circle.circle_id == circle_id)
    )
    if not circle:
        return None, "not_found"
    if circle.is_system:
        return None, "system_immutable"
    name = name.strip()
    if not name:
        return None, "invalid_name"
    existing = db.scalar(
        select(Circle).where(
            Circle.owner_id == owner_id,
            Circle.name == name,
            Circle.circle_id != circle_id,
        )
    )
    if existing:
        return None, "name_taken"
    circle.name = name
    db.commit()
    db.refresh(circle)
    return circle, None


def delete_circle(db: OrmSession, owner_id: int, circle_id: int) -> str | None:
    circle = db.scalar(
        select(Circle).where(Circle.owner_id == owner_id, Circle.circle_id == circle_id)
    )
    if not circle:
        return "not_found"
    if circle.is_system:
        return "system_immutable"
    member_ids = [
        member.member_user_id
        for member in db.scalars(
            select(CircleMember).where(CircleMember.circle_id == circle_id)
        ).all()
    ]
    db.query(CircleMember).filter(CircleMember.circle_id == circle_id).delete()
    db.delete(circle)
    db.commit()
    for member_id in member_ids:
        _update_no_circles_assigned(db, owner_id, member_id)
    return None


def add_members_batch(
    db: OrmSession, owner_id: int, circle_id: int, member_ids: list[int]
) -> tuple[int | None, str | None]:
    circle = db.scalar(
        select(Circle).where(Circle.owner_id == owner_id, Circle.circle_id == circle_id)
    )
    if not circle:
        return None, "not_found"
    unique_ids = list(dict.fromkeys(member_ids))
    if len(unique_ids) > 100:
        return None, "batch_limit"
    if not unique_ids:
        return 0, None
    existing_count = db.scalar(
        select(func.count()).select_from(CircleMember).where(CircleMember.circle_id == circle_id)
    )
    if existing_count is None:
        existing_count = 0
    if existing_count + len(unique_ids) > 500:
        return None, "member_limit"
    for member_id in unique_ids:
        if not are_friends(db, owner_id, member_id):
            return None, "member_not_friend"
    added = 0
    for member_id in unique_ids:
        exists = db.scalar(
            select(CircleMember).where(
                CircleMember.circle_id == circle_id,
                CircleMember.member_user_id == member_id,
            )
        )
        if exists:
            continue
        db.add(CircleMember(circle_id=circle_id, member_user_id=member_id))
        added += 1
    db.commit()
    for member_id in unique_ids:
        if are_friends(db, owner_id, member_id):
            _update_no_circles_assigned(db, owner_id, member_id)
    return added, None


def remove_member(
    db: OrmSession, owner_id: int, circle_id: int, member_id: int
) -> str | None:
    circle = db.scalar(
        select(Circle).where(Circle.owner_id == owner_id, Circle.circle_id == circle_id)
    )
    if not circle:
        return "not_found"
    membership = db.scalar(
        select(CircleMember).where(
            CircleMember.circle_id == circle_id,
            CircleMember.member_user_id == member_id,
        )
    )
    if not membership:
        return "membership_not_found"
    db.delete(membership)
    db.commit()
    _update_no_circles_assigned(db, owner_id, member_id)
    return None


def _update_no_circles_assigned(db: OrmSession, owner_id: int, member_id: int) -> None:
    friendship = db.scalar(
        select(Friendship).where(
            Friendship.user_id == owner_id,
            Friendship.friend_id == member_id,
        )
    )
    if not friendship:
        return
    circle_ids = db.scalars(
        select(Circle.circle_id).where(Circle.owner_id == owner_id)
    ).all()
    if not circle_ids:
        friendship.no_circles_assigned = True
        db.commit()
        return
    membership_count = db.scalar(
        select(func.count())
        .select_from(CircleMember)
        .where(
            CircleMember.member_user_id == member_id,
            CircleMember.circle_id.in_(circle_ids),
        )
    )
    friendship.no_circles_assigned = membership_count == 0
    db.commit()
