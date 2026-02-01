from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.models.circle import Circle
from app.models.user import User


def set_status(
    db: OrmSession,
    user: User,
    status: str,
    visible_circle_ids: list[int],
) -> tuple[User | None, str | None]:
    if visible_circle_ids:
        unique_ids = list(dict.fromkeys(visible_circle_ids))
        circles = db.scalars(
            select(Circle).where(
                Circle.owner_id == user.user_id,
                Circle.circle_id.in_(unique_ids),
            )
        ).all()
        if len(circles) != len(unique_ids):
            return None, "circle_not_found"
    user.status = status
    user.status_visible_circle_ids = visible_circle_ids
    db.commit()
    db.refresh(user)
    return user, None
