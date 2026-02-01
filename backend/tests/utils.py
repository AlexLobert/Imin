from app.db.database import Base, engine
from app.models import block  # noqa: F401
from app.models import circle  # noqa: F401
from app.models import circle_member  # noqa: F401
from app.models import device  # noqa: F401
from app.models import friend_request  # noqa: F401
from app.models import friendship  # noqa: F401
from app.models import message  # noqa: F401
from app.models import rate_limit  # noqa: F401
from app.models import report  # noqa: F401
from app.models import session  # noqa: F401
from app.models import thread  # noqa: F401
from app.models import thread_read  # noqa: F401
from app.models import user  # noqa: F401


def reset_db() -> None:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
