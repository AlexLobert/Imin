from datetime import datetime

from pydantic import BaseModel


class ReportCreate(BaseModel):
    target_user_id: int
    reason: str
    details: str | None = None


class ReportResponse(BaseModel):
    report_id: int
    target_user_id: int
    reason: str
    details: str | None = None
    status: str
    created_at: datetime
