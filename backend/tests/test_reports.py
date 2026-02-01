from fastapi.testclient import TestClient

from app.main import app
from tests.utils import reset_db


client = TestClient(app)


def setup_function() -> None:
    reset_db()
    client.cookies.clear()


def _create_user(email: str) -> None:
    client.post("/create_account", json={"email": email, "password": "StrongPass1!"})


def _login(email: str) -> None:
    client.post("/login", json={"email": email, "password": "StrongPass1!"})


def _get_user_id(email: str) -> int:
    _login(email)
    user_id = client.get("/me").json()["user_id"]
    client.cookies.clear()
    return user_id


def test_report_create() -> None:
    _create_user("reporter@example.com")
    _create_user("target@example.com")
    target_id = _get_user_id("target@example.com")

    _login("reporter@example.com")
    report = client.post(
        "/reports", json={"target_user_id": target_id, "reason": "spam"}
    )
    assert report.status_code == 201
    assert report.json()["status"] == "new"
