# Imin Backend v0.1.0

## Setup
```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

## Run
```bash
uvicorn app.main:app --reload
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
