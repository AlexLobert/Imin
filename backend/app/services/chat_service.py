from datetime import datetime, timezone

from sqlalchemy import desc, select
from sqlalchemy.orm import Session as OrmSession

from app.models.message import Message
from app.models.thread import Thread
from app.models.thread_read import ThreadRead
from app.services.rate_limit_service import check_rate_limit
from app.services.relationship_service import are_friends, is_blocked


MESSAGE_LIMIT = 2000


def list_threads(db: OrmSession, user_id: int) -> list[tuple[Thread, Message | None]]:
    threads = db.scalars(
        select(Thread).where(
            (Thread.user_low_id == user_id) | (Thread.user_high_id == user_id)
        )
    ).all()
    results: list[tuple[Thread, Message | None]] = []
    for thread in threads:
        last_message = db.scalar(
            select(Message)
            .where(Message.thread_id == thread.thread_id)
            .order_by(desc(Message.created_at))
        )
        results.append((thread, last_message))
    results.sort(key=lambda item: item[0].created_at, reverse=True)
    return results


def open_or_create_thread(
    db: OrmSession, user_id: int, other_user_id: int
) -> tuple[Thread | None, str | None]:
    if user_id == other_user_id:
        return None, "not_allowed"
    if is_blocked(db, user_id, other_user_id):
        return None, "blocked"
    if not are_friends(db, user_id, other_user_id):
        return None, "not_friends"
    low_id, high_id = sorted([user_id, other_user_id])
    existing = db.scalar(
        select(Thread).where(Thread.user_low_id == low_id, Thread.user_high_id == high_id)
    )
    if existing:
        return existing, None
    thread = Thread(user_low_id=low_id, user_high_id=high_id)
    db.add(thread)
    db.commit()
    db.refresh(thread)
    for participant_id in (user_id, other_user_id):
        read_state = ThreadRead(thread_id=thread.thread_id, user_id=participant_id)
        db.add(read_state)
    db.commit()
    return thread, None


def list_messages(
    db: OrmSession,
    user_id: int,
    thread_id: int,
    before: int | None,
    limit: int,
) -> tuple[list[Message] | None, str | None]:
    thread = _get_thread_for_user(db, user_id, thread_id)
    if not thread:
        return None, "not_found"
    if limit <= 0:
        limit = 50
    limit = min(limit, 100)
    query = select(Message).where(Message.thread_id == thread_id)
    if before is not None:
        query = query.where(Message.message_id < before)
    messages = db.scalars(query.order_by(desc(Message.message_id)).limit(limit)).all()
    return messages, None


def create_message(
    db: OrmSession, user_id: int, thread_id: int, text: str
) -> tuple[Message | None, str | None]:
    thread = _get_thread_for_user(db, user_id, thread_id)
    if not thread:
        return None, "thread_not_found"
    other_user_id = thread.user_high_id if thread.user_low_id == user_id else thread.user_low_id
    if is_blocked(db, user_id, other_user_id):
        return None, "blocked"
    if not are_friends(db, user_id, other_user_id):
        return None, "not_friends"
    cleaned = text.strip()
    if not cleaned:
        return None, "invalid_text"
    if len(cleaned) > MESSAGE_LIMIT:
        return None, "too_long"
    if not check_rate_limit(db, user_id, "messages_per_minute", 30, 60):
        return None, "rate_limited"
    if not check_rate_limit(db, user_id, "messages_per_hour", 300, 3600):
        return None, "rate_limited"
    message = Message(thread_id=thread_id, sender_id=user_id, text=cleaned)
    db.add(message)
    db.commit()
    db.refresh(message)
    _update_read_state(db, thread_id, user_id, message.message_id)
    return message, None


def mark_read(
    db: OrmSession, user_id: int, thread_id: int, last_read_message_id: int
) -> str | None:
    thread = _get_thread_for_user(db, user_id, thread_id)
    if not thread:
        return "thread_not_found"
    message = db.scalar(
        select(Message).where(
            Message.thread_id == thread_id,
            Message.message_id == last_read_message_id,
        )
    )
    if not message:
        return "message_not_found"
    _update_read_state(db, thread_id, user_id, last_read_message_id)
    return None


def _get_thread_for_user(db: OrmSession, user_id: int, thread_id: int) -> Thread | None:
    return db.scalar(
        select(Thread).where(
            Thread.thread_id == thread_id,
            (Thread.user_low_id == user_id) | (Thread.user_high_id == user_id),
        )
    )


def _update_read_state(
    db: OrmSession, thread_id: int, user_id: int, message_id: int
) -> None:
    read_state = db.scalar(
        select(ThreadRead).where(
            ThreadRead.thread_id == thread_id,
            ThreadRead.user_id == user_id,
        )
    )
    if not read_state:
        read_state = ThreadRead(
            thread_id=thread_id, user_id=user_id, last_read_message_id=message_id
        )
        db.add(read_state)
    else:
        read_state.last_read_message_id = message_id
        read_state.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
