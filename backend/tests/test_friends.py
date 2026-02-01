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


def test_friend_request_flow_and_remove() -> None:
    _create_user("one@example.com", "one")
    _create_user("two@example.com", "two")

    _login("one@example.com")
    response = client.post("/friend-requests", json={"username": "two"})
    assert response.status_code == 201
    request_id = response.json()["request_id"]

    duplicate = client.post("/friend-requests", json={"username": "two"})
    assert duplicate.status_code == 409
    assert duplicate.json()["error"]["code"] == "FRIEND_REQUEST_ALREADY_EXISTS"

    client.cookies.clear()
    _login("two@example.com")
    incoming = client.get("/friend-requests", params={"type": "incoming"})
    assert incoming.status_code == 200
    assert incoming.json()["items"]

    accept = client.patch(
        f"/friend-requests/{request_id}",
        json={"status": "accepted"},
    )
    assert accept.status_code == 200

    client.cookies.clear()
    _login("one@example.com")
    friends = client.get("/friends")
    assert friends.status_code == 200
    assert len(friends.json()["items"]) == 1
    friend_id = friends.json()["items"][0]["user_id"]

    remove = client.delete(f"/friends/{friend_id}")
    assert remove.status_code == 204
    assert client.get("/friends").json()["items"] == []


def test_block_prevents_friend_request() -> None:
    _create_user("blocker@example.com", "blocker")
    _create_user("blocked@example.com", "blocked")

    _login("blocker@example.com")
    blocker_id = client.get("/me").json()["user_id"]
    client.cookies.clear()

    _login("blocked@example.com")
    blocked_id = client.get("/me").json()["user_id"]
    client.cookies.clear()

    _login("blocker@example.com")
    block = client.post("/blocks", json={"user_id": blocked_id})
    assert block.status_code == 201

    client.cookies.clear()
    _login("blocked@example.com")
    request = client.post("/friend-requests", json={"username": "blocker"})
    assert request.status_code == 403
    assert request.json()["error"]["code"] == "USER_BLOCKED"
