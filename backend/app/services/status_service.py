from sqlalchemy.orm import Session as OrmSession

from app.models.user import User


def set_status(db: OrmSession, user: User, status: str) -> str:
    user.status = status
    db.commit()
    db.refresh(user)
    return user.status
