from sqlalchemy import Integer, String, JSON
from sqlalchemy.ext.mutable import MutableDict, MutableList
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    first_name: Mapped[str | None] = mapped_column(String, nullable=True)
    last_name: Mapped[str | None] = mapped_column(String, nullable=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="Out")
    friends_list: Mapped[list[int]] = mapped_column(
        MutableList.as_mutable(JSON), default=list, nullable=False
    )
    circles: Mapped[dict[str, list[int]]] = mapped_column(
        MutableDict.as_mutable(JSON), default=dict, nullable=False
    )
