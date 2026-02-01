from fastapi.testclient import TestClient

from tests.utils import reset_db
from app.main import app
client = TestClient(app)


def setup_function() -> None:
    reset_db()
    client.cookies.clear()


def _login_and_get_everyone_circle() -> int:
    client.post(
        "/create_account",
        json={"email": "status@example.com", "password": "StrongPass1!"},
    )
    client.post(
        "/login",
        json={"email": "status@example.com", "password": "StrongPass1!"},
    )
    circles = client.get("/circles")
    assert circles.status_code == 200
    items = circles.json()["items"]
    assert items
    return items[0]["circle_id"]


def test_set_status_requires_auth() -> None:
    response = client.post("/set_status", json={"status": "In", "visible_circle_ids": []})
    assert response.status_code == 401
    assert response.json() == {
        "error": {"code": "UNAUTHORIZED", "message": "auth required"}
    }


def test_set_status_invalid_value() -> None:
    circle_id = _login_and_get_everyone_circle()
    response = client.post(
        "/set_status",
        json={"status": "Maybe", "visible_circle_ids": [circle_id]},
    )
    assert response.status_code == 422
    payload = response.json()
    assert payload["error"]["code"] == "VALIDATION_ERROR"


def test_set_status_success() -> None:
    circle_id = _login_and_get_everyone_circle()
    response = client.post(
        "/set_status",
        json={"status": "In", "visible_circle_ids": [circle_id]},
    )
    assert response.status_code == 200
    assert response.json() == {
        "status": "In",
        "visible_circle_ids": [circle_id],
        "message": "status updated",
    }
