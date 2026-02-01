from fastapi.testclient import TestClient

from tests.utils import reset_db
from app.main import app


client = TestClient(app)


def setup_function() -> None:
    reset_db()
    client.cookies.clear()


def test_create_account_success() -> None:
    response = client.post(
        "/create_account",
        json={"email": "a@example.com", "password": "StrongPass1!"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "a@example.com"
    assert body["message"] == "account created"
    assert isinstance(body["user_id"], str)


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
        "error": {
            "code": "EMAIL_IN_USE",
            "message": "this email address is already associated with an account",
        }
    }


def test_create_account_bad_password() -> None:
    response = client.post(
        "/create_account",
        json={"email": "weak@example.com", "password": "weakpass"},
    )
    assert response.status_code == 400
    payload = response.json()
    assert payload["error"]["code"] == "PASSWORD_INVALID"
    message = payload["error"]["message"]
    assert "10" in message
    assert "capital" in message
    assert "number" in message
    assert "special" in message


def test_login_wrong_password() -> None:
    response = client.post(
        "/login",
        json={"email": "missing@example.com", "password": "StrongPass1!"},
    )
    assert response.status_code == 401
    assert response.json() == {
        "error": {"code": "INVALID_CREDENTIALS", "message": "info wrong. me no open"}
    }


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
    status = client.post("/set_status", json={"status": "In", "visible_circle_ids": []})
    assert status.status_code == 401
