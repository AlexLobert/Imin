from datetime import datetime, timedelta
import secrets

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.config.settings import SESSION_TTL_DAYS
from app.models.session import Session as SessionModel
from app.models.user import User


def create_session(db: OrmSession, user_id: int) -> tuple[str, datetime]:
    session_id = secrets.token_urlsafe(32)
    created_at = datetime.utcnow()
    expires_at = created_at + timedelta(days=SESSION_TTL_DAYS)
    session = SessionModel(
        session_id=session_id,
        user_id=user_id,
        created_at=created_at,
        expires_at=expires_at,
    )
    db.add(session)
    db.commit()
    return session_id, expires_at


def delete_session(db: OrmSession, session_id: str | None) -> None:
    if not session_id:
        return
    session = db.scalar(select(SessionModel).where(SessionModel.session_id == session_id))
    if session:
        db.delete(session)
        db.commit()


def get_user_for_session(db: OrmSession, session_id: str | None) -> User | None:
    if not session_id:
        return None
    session = db.scalar(select(SessionModel).where(SessionModel.session_id == session_id))
    if not session:
        return None
    if session.expires_at < datetime.utcnow():
        db.delete(session)
        db.commit()
        return None
    return db.scalar(select(User).where(User.user_id == session.user_id))
