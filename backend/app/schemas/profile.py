from datetime import datetime

from pydantic import BaseModel, EmailStr


class MeResponse(BaseModel):
    user_id: int
    email: EmailStr | None
    name: str | None
    handle: str | None
    created_at: datetime | None


class MePatchRequest(BaseModel):
    name: str | None = None
    handle: str | None = None


class HandleAvailableResponse(BaseModel):
    available: bool
