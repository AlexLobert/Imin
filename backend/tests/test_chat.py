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
    me = client.get("/me")
    client.cookies.clear()
    return me.json()["user_id"]


def _friend_users() -> None:
    _login("one@example.com")
    response = client.post("/friend-requests", json={"username": "two"})
    request_id = response.json()["request_id"]
    client.cookies.clear()
    _login("two@example.com")
    client.patch(f"/friend-requests/{request_id}", json={"status": "accepted"})
    client.cookies.clear()


def test_chat_requires_friendship() -> None:
    _create_user("one@example.com", "one")
    _create_user("two@example.com", "two")

    user_two_id = _get_user_id("two@example.com")
    _login("one@example.com")
    not_friends = client.post("/threads", json={"other_user_id": user_two_id})
    assert not_friends.status_code == 403
    assert not_friends.json()["error"]["code"] == "NOT_FRIENDS"

    client.cookies.clear()
    _friend_users()

    _login("one@example.com")
    thread = client.post("/threads", json={"other_user_id": user_two_id})
    assert thread.status_code == 201
    thread_id = thread.json()["thread_id"]

    message = client.post(f"/threads/{thread_id}/messages", json={"text": "hi"})
    assert message.status_code == 201

    messages = client.get(f"/threads/{thread_id}/messages")
    assert messages.status_code == 200
    assert messages.json()["items"][0]["text"] == "hi"
