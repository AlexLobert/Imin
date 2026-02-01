from sqlalchemy.orm import Session as OrmSession

from app.models.report import Report
from app.services.rate_limit_service import check_rate_limit


def create_report(
    db: OrmSession,
    reporter_user_id: int,
    target_user_id: int,
    reason: str,
    details: str | None,
) -> tuple[Report | None, str | None]:
    if not check_rate_limit(db, reporter_user_id, "reports_daily", 10, 86400):
        return None, "rate_limited"
    cleaned_reason = reason.strip()
    if not cleaned_reason:
        return None, "invalid_reason"
    report = Report(
        reporter_user_id=reporter_user_id,
        target_user_id=target_user_id,
        reason=cleaned_reason,
        details=details.strip() if details else None,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report, None
