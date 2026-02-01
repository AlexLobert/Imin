from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class Thread(Base):
    __tablename__ = "threads"
    __table_args__ = (
        UniqueConstraint("user_low_id", "user_high_id", name="uq_thread_pair"),
    )

    thread_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_low_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    user_high_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)
