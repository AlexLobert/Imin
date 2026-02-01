from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.models.device import Device


ALLOWED_PLATFORMS = {"ios"}


def register_device(
    db: OrmSession,
    user_id: int,
    platform: str,
    token: str,
    device_identifier: str | None,
) -> tuple[Device | None, str | None]:
    cleaned_token = token.strip()
    cleaned_platform = platform.strip().lower()
    if not cleaned_token or not cleaned_platform:
        return None, "invalid"
    if cleaned_platform not in ALLOWED_PLATFORMS:
        return None, "invalid"
    existing = db.scalar(select(Device).where(Device.token == cleaned_token))
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if existing:
        existing.user_id = user_id
        existing.platform = cleaned_platform
        existing.device_identifier = device_identifier
        existing.updated_at = now
        db.commit()
        db.refresh(existing)
        return existing, None
    device = Device(
        user_id=user_id,
        platform=cleaned_platform,
        token=cleaned_token,
        device_identifier=device_identifier,
        created_at=now,
        updated_at=now,
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return device, None


def delete_device(db: OrmSession, user_id: int, device_id: int) -> bool:
    deleted = (
        db.query(Device)
        .filter(Device.user_id == user_id, Device.device_id == device_id)
        .delete()
    )
    db.commit()
    return deleted > 0
