from pathlib import Path
import os


BASE_DIR = Path(__file__).resolve().parents[2]
DATABASE_URL = os.environ.get(
    "IMIN_DATABASE_URL",
    f"sqlite:///{BASE_DIR / 'app.db'}",
)

SESSION_COOKIE_NAME = os.environ.get("IMIN_SESSION_COOKIE", "imin_session")
SESSION_TTL_DAYS = int(os.environ.get("IMIN_SESSION_TTL_DAYS", "7"))
SESSION_COOKIE_SECURE = (
    os.environ.get("IMIN_SESSION_COOKIE_SECURE", "false").lower() == "true"
)
