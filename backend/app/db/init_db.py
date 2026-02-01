from sqlalchemy import inspect, text

from app.db.database import Base, engine
from app.models import block as block_model  # noqa: F401
from app.models import circle as circle_model  # noqa: F401
from app.models import circle_member as circle_member_model  # noqa: F401
from app.models import device as device_model  # noqa: F401
from app.models import friend_request as friend_request_model  # noqa: F401
from app.models import friendship as friendship_model  # noqa: F401
from app.models import message as message_model  # noqa: F401
from app.models import rate_limit as rate_limit_model  # noqa: F401
from app.models import report as report_model  # noqa: F401
from app.models import session as session_model  # noqa: F401
from app.models import thread as thread_model  # noqa: F401
from app.models import thread_read as thread_read_model  # noqa: F401
from app.models import user as user_model  # noqa: F401


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    _ensure_user_columns()


def _ensure_user_columns() -> None:
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return
    existing = {col["name"] for col in inspector.get_columns("users")}
    with engine.begin() as conn:
        if "created_at" not in existing:
            conn.execute(text("ALTER TABLE users ADD COLUMN created_at DATETIME"))
        if "name" not in existing:
            conn.execute(text("ALTER TABLE users ADD COLUMN name VARCHAR"))
        if "handle" not in existing:
            conn.execute(text("ALTER TABLE users ADD COLUMN handle VARCHAR"))
        if "status_visible_circle_ids" not in existing:
            conn.execute(
                text("ALTER TABLE users ADD COLUMN status_visible_circle_ids JSON")
            )
        conn.execute(
            text(
                "UPDATE users SET status_visible_circle_ids='[]' "
                "WHERE status_visible_circle_ids IS NULL"
            )
        )
        conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_handle "
                "ON users (handle)"
            )
        )
