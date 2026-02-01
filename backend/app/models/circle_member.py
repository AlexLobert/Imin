from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class CircleMember(Base):
    __tablename__ = "circle_members"
    __table_args__ = (
        UniqueConstraint("circle_id", "member_user_id", name="uq_circle_member"),
    )

    circle_member_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    circle_id: Mapped[int] = mapped_column(Integer, ForeignKey("circles.circle_id"), nullable=False, index=True)
    member_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)
