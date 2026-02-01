from fastapi.testclient import TestClient

from app.main import app
from tests.utils import reset_db


client = TestClient(app)


def setup_function() -> None:
    reset_db()
    client.cookies.clear()


def _create_and_login() -> None:
    client.post("/create_account", json={"email": "device@example.com", "password": "StrongPass1!"})
    client.post("/login", json={"email": "device@example.com", "password": "StrongPass1!"})


def test_device_register_and_delete() -> None:
    _create_and_login()
    first = client.post(
        "/devices", json={"platform": "ios", "token": "token-1", "device_id": "a"}
    )
    assert first.status_code == 201
    device_id = first.json()["device_id"]

    second = client.post(
        "/devices", json={"platform": "ios", "token": "token-1", "device_id": "b"}
    )
    assert second.status_code == 201
    assert second.json()["device_id"] == device_id

    delete = client.delete(f"/devices/{device_id}")
    assert delete.status_code == 204
