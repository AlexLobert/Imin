# Imin Backend v0.1.0

## Setup
### Windows
```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

### macOS / Linux
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run
```bash
uvicorn app.main:app --reload
```

## API Docs
- OpenAPI JSON: `GET /openapi.json`
- Swagger UI: `GET /docs`
- ReDoc UI: `GET /redoc`

## Endpoints Summary
- Auth: `POST /create_account`, `POST /login`, `POST /logout`
- Profile: `GET /me`, `PATCH /me`, `GET /handles/{handle}/available`
- Status: `POST /set_status`
- Friends: `GET /friends`, `GET /friends/unassigned`, `DELETE /friends/{friendId}`, `POST /friend-requests`, `GET /friend-requests`, `PATCH /friend-requests/{id}`, `POST /blocks`, `DELETE /blocks/{userId}`, `GET /blocks`
- Circles: `GET /circles`, `POST /circles`, `PATCH /circles/{id}`, `DELETE /circles/{id}`, `POST /circles/{id}/members`, `DELETE /circles/{id}/members/{memberId}`
- Chat: `GET /threads`, `POST /threads`, `GET /threads/{id}/messages`, `POST /threads/{id}/messages`, `POST /threads/{id}/read`
- Discovery: `GET /in_now`
- Devices: `POST /devices`, `DELETE /devices/{id}`
- Safety: `POST /reports`

## Export OpenAPI
From the repo root:
```bash
python backend/scripts/export_openapi.py
```

Using the backend virtual environment:
```bash
backend/.venv/Scripts/python.exe backend/scripts/export_openapi.py
```

## Tests
```bash
pytest
```

## Notes
- Uses SQLite by default at `backend/app.db`.
- Tables are created automatically on startup (no Alembic migrations for v0.1.0).
- `pytest.ini` config sets `pythonpath = .` for test imports.
- Requirements include `pydantic[email]` (for `EmailStr`) and `bcrypt<5` for passlib compatibility.
