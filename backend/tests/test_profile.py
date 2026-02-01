from fastapi.testclient import TestClient

from app.main import app
from tests.utils import reset_db


client = TestClient(app)


def setup_function() -> None:
    reset_db()
    client.cookies.clear()


def _create_and_login(email: str) -> None:
    client.post("/create_account", json={"email": email, "password": "StrongPass1!"})
    client.post("/login", json={"email": email, "password": "StrongPass1!"})


def test_handle_available_and_patch_me() -> None:
    _create_and_login("one@example.com")
    patch = client.patch("/me", json={"name": "Alex", "handle": "alex"})
    assert patch.status_code == 200
    me = patch.json()
    assert me["name"] == "Alex"
    assert me["handle"] == "alex"

    client.cookies.clear()
    available = client.get("/handles/alex/available")
    assert available.status_code == 200
    assert available.json() == {"available": False}

    client.cookies.clear()
    _create_and_login("two@example.com")
    conflict = client.patch("/me", json={"handle": "alex"})
    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "HANDLE_NOT_AVAILABLE"
