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


def _friend_users() -> None:
    _login("one@example.com")
    response = client.post("/friend-requests", json={"username": "two"})
    request_id = response.json()["request_id"]
    client.cookies.clear()
    _login("two@example.com")
    client.patch(f"/friend-requests/{request_id}", json={"status": "accepted"})
    client.cookies.clear()


def test_circles_everyone_and_unassigned() -> None:
    _create_user("one@example.com", "one")
    _create_user("two@example.com", "two")
    _friend_users()

    _login("one@example.com")
    circles = client.get("/circles")
    assert circles.status_code == 200
    items = circles.json()["items"]
    everyone = next(item for item in items if item["name"] == "Everyone")

    rename = client.patch(f"/circles/{everyone['circle_id']}", json={"name": "All"})
    assert rename.status_code == 409
    assert rename.json()["error"]["code"] == "CIRCLE_SYSTEM_IMMUTABLE"

    friend_id = client.get("/friends").json()["items"][0]["user_id"]
    remove = client.delete(f"/circles/{everyone['circle_id']}/members/{friend_id}")
    assert remove.status_code == 204

    unassigned = client.get("/friends/unassigned")
    assert unassigned.status_code == 200
    assert unassigned.json()["items"]

    create = client.post("/circles", json={"name": "Close"})
    assert create.status_code == 201
    circle_id = create.json()["circle_id"]

    add = client.post(
        f"/circles/{circle_id}/members", json={"member_ids": [friend_id]}
    )
    assert add.status_code == 200

    unassigned_after = client.get("/friends/unassigned")
    assert unassigned_after.status_code == 200
    assert unassigned_after.json()["items"] == []
