from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.auth.password import hash_password, validate_password, verify_password
from app.auth.session import create_session, delete_session
from app.models.user import User
from app.services.circles_service import ensure_everyone_circle


def create_account(
    db: OrmSession,
    email: str,
    password: str,
    first_name: str | None,
    last_name: str | None,
) -> tuple[User | None, str | None]:
    existing = db.scalar(select(User).where(User.email == email))
    if existing:
        return None, "duplicate_email"
    valid, error = validate_password(password)
    if not valid:
        return None, error
    user = User(
        email=email,
        password_hash=hash_password(password),
        first_name=first_name,
        last_name=last_name,
        status="Out",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    ensure_everyone_circle(db, user.user_id)
    return user, None


def login(db: OrmSession, email: str, password: str) -> str | None:
    user = db.scalar(select(User).where(User.email == email))
    if not user:
        return None
    if not verify_password(password, user.password_hash):
        return None
    session_id, _ = create_session(db, user.user_id)
    return session_id


def logout(db: OrmSession, session_id: str | None) -> None:
    delete_session(db, session_id)
