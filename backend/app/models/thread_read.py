from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class ThreadRead(Base):
    __tablename__ = "thread_reads"
    __table_args__ = (
        UniqueConstraint("thread_id", "user_id", name="uq_thread_read"),
    )

    thread_read_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    thread_id: Mapped[int] = mapped_column(Integer, ForeignKey("threads.thread_id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    last_read_message_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("messages.message_id"), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False)
