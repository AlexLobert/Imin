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


def _friend_users() -> int:
    _login("sender@example.com")
    response = client.post("/friend-requests", json={"username": "receiver"})
    request_id = response.json()["request_id"]
    client.cookies.clear()
    _login("receiver@example.com")
    client.patch(f"/friend-requests/{request_id}", json={"status": "accepted"})
    client.cookies.clear()
    return request_id


def test_friend_request_daily_limit() -> None:
    _create_user("sender@example.com", "sender")
    for i in range(1, 22):
        _create_user(f"user{i}@example.com", f"user{i}")

    _login("sender@example.com")
    last_status = None
    for i in range(1, 22):
        response = client.post("/friend-requests", json={"username": f"user{i}"})
        last_status = response.status_code
        if i <= 20:
            assert response.status_code == 201
        else:
            assert response.status_code == 429
            assert response.json()["error"]["code"] == "RATE_LIMITED"
    assert last_status == 429


def test_message_rate_limit_per_minute() -> None:
    _create_user("sender@example.com", "sender")
    _create_user("receiver@example.com", "receiver")
    receiver_id = _get_user_id("receiver@example.com")
    _friend_users()

    _login("sender@example.com")
    thread = client.post("/threads", json={"other_user_id": receiver_id})
    thread_id = thread.json()["thread_id"]

    last_status = None
    for i in range(1, 32):
        response = client.post(
            f"/threads/{thread_id}/messages",
            json={"text": f"msg {i}"},
        )
        last_status = response.status_code
        if i <= 30:
            assert response.status_code == 201
        else:
            assert response.status_code == 429
            assert response.json()["error"]["code"] == "RATE_LIMITED"
    assert last_status == 429
