from sqlalchemy import func, select
from sqlalchemy.orm import Session as OrmSession

from app.models.user import User


def is_handle_available(db: OrmSession, handle: str, current_user_id: int | None = None) -> bool:
    normalized = handle.strip().lower()
    if not normalized:
        return False
    query = select(User).where(func.lower(User.handle) == normalized)
    user = db.scalar(query)
    if not user:
        return True
    if current_user_id is not None and user.user_id == current_user_id:
        return True
    return False


def update_profile(
    db: OrmSession,
    user: User,
    name: str | None,
    handle: str | None,
) -> tuple[User | None, str | None]:
    if name is not None:
        cleaned = name.strip()
        user.name = cleaned if cleaned else None
    if handle is not None:
        normalized = handle.strip().lower()
        if not normalized:
            return None, "invalid_handle"
        if not is_handle_available(db, normalized, current_user_id=user.user_id):
            return None, "handle_taken"
        user.handle = normalized
    db.commit()
    db.refresh(user)
    return user, None
