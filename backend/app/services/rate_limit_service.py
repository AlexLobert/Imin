from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.models.rate_limit import RateLimit


def check_rate_limit(
    db: OrmSession,
    user_id: int,
    key: str,
    limit: int,
    window_seconds: int,
) -> bool:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    entry = db.scalar(
        select(RateLimit).where(RateLimit.user_id == user_id, RateLimit.key == key)
    )
    if not entry:
        entry = RateLimit(user_id=user_id, key=key, window_start=now, count=1)
        db.add(entry)
        db.commit()
        return True
    window_end = entry.window_start + timedelta(seconds=window_seconds)
    if now >= window_end:
        entry.window_start = now
        entry.count = 1
        db.commit()
        return True
    if entry.count >= limit:
        return False
    entry.count += 1
    db.commit()
    return True
