from fastapi.testclient import TestClient

from app.db.database import SessionLocal
from app.db.init_db import init_db
from app.main import app
from app.models.session import Session
from app.models.user import User


client = TestClient(app)


def _clear_db() -> None:
    with SessionLocal() as db:
        db.query(Session).delete()
        db.query(User).delete()
        db.commit()


def setup_function() -> None:
    init_db()
    _clear_db()
    client.cookies.clear()


def _login() -> None:
    client.post(
        "/create_account",
        json={"email": "status@example.com", "password": "StrongPass1!"},
    )
    client.post(
        "/login",
        json={"email": "status@example.com", "password": "StrongPass1!"},
    )


def test_set_status_requires_auth() -> None:
    response = client.post("/set_status", json={"status": "In"})
    assert response.status_code == 401
    assert response.json() == {
        "error": {"code": "UNAUTHORIZED", "message": "auth required"}
    }


def test_set_status_invalid_value() -> None:
    _login()
    response = client.post("/set_status", json={"status": "Maybe"})
    assert response.status_code == 422
    payload = response.json()
    assert payload["error"]["code"] == "VALIDATION_ERROR"


def test_set_status_success() -> None:
    _login()
    response = client.post("/set_status", json={"status": "In"})
    assert response.status_code == 200
    assert response.json() == {"status": "In", "message": "status updated"}
