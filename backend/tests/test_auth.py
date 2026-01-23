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


def test_create_account_success() -> None:
    response = client.post(
        "/create_account",
        json={"email": "a@example.com", "password": "StrongPass1!", "first_name": "A"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["ok"] is True
    assert isinstance(body["user_id"], int)


def test_create_account_duplicate_email() -> None:
    client.post(
        "/create_account",
        json={"email": "dup@example.com", "password": "StrongPass1!"},
    )
    response = client.post(
        "/create_account",
        json={"email": "dup@example.com", "password": "StrongPass1!"},
    )
    assert response.status_code == 409
    assert response.json() == {
        "ok": False,
        "error": "this email address is already associated with an account",
    }


def test_create_account_bad_password() -> None:
    response = client.post(
        "/create_account",
        json={"email": "weak@example.com", "password": "weakpass"},
    )
    assert response.status_code == 400
    error = response.json()["error"]
    assert "10" in error
    assert "capital" in error
    assert "number" in error
    assert "special" in error


def test_login_wrong_password() -> None:
    response = client.post(
        "/login",
        json={"email": "missing@example.com", "password": "StrongPass1!"},
    )
    assert response.status_code == 401
    assert response.json() == {"ok": False, "error": "info wrong. me no open"}


def test_logout_clears_auth() -> None:
    client.post(
        "/create_account",
        json={"email": "out@example.com", "password": "StrongPass1!"},
    )
    login = client.post(
        "/login",
        json={"email": "out@example.com", "password": "StrongPass1!"},
    )
    assert login.status_code == 200
    logout = client.post("/logout")
    assert logout.status_code == 200
    status = client.post("/set_status", json={"status": "In"})
    assert status.status_code == 401
