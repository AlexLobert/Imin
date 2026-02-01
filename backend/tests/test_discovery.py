from fastapi.testclient import TestClient

from app.main import app
from tests.utils import reset_db


client = TestClient(app)


def setup_function() -> None:
    reset_db()
    client.cookies.clear()


def _create_user(email: str, handle: str) -> None:
    client.post("/create_account", json={"email": email, "password": "StrongPass1!"})
    client.post("/login", json={"email": email, "password": "StrongPass1!"})
    client.patch("/me", json={"handle": handle})
    client.cookies.clear()


def _login(email: str) -> None:
    client.post("/login", json={"email": email, "password": "StrongPass1!"})


def _get_user_id(email: str) -> int:
    _login(email)
    user_id = client.get("/me").json()["user_id"]
    client.cookies.clear()
    return user_id


def _friend_users() -> None:
    _login("one@example.com")
    response = client.post("/friend-requests", json={"username": "two"})
    request_id = response.json()["request_id"]
    client.cookies.clear()
    _login("two@example.com")
    client.patch(f"/friend-requests/{request_id}", json={"status": "accepted"})
    client.cookies.clear()


def test_in_now_respects_visibility() -> None:
    _create_user("one@example.com", "one")
    _create_user("two@example.com", "two")
    _friend_users()

    user_one_id = _get_user_id("one@example.com")

    _login("two@example.com")
    circles = client.get("/circles").json()["items"]
    everyone_id = next(item["circle_id"] for item in circles if item["name"] == "Everyone")
    status = client.post(
        "/set_status",
        json={"status": "In", "visible_circle_ids": [everyone_id]},
    )
    assert status.status_code == 200

    client.cookies.clear()
    _login("one@example.com")
    visible = client.get("/in_now")
    assert visible.status_code == 200
    assert visible.json()["items"]

    client.cookies.clear()
    _login("two@example.com")
    client.delete(f"/circles/{everyone_id}/members/{user_one_id}")
    client.post(
        "/set_status",
        json={"status": "In", "visible_circle_ids": [everyone_id]},
    )

    client.cookies.clear()
    _login("one@example.com")
    hidden = client.get("/in_now")
    assert hidden.status_code == 200
    assert hidden.json()["items"] == []
