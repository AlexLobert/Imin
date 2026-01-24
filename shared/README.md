# Shared API Contract

This folder contains the shared API contract artifacts used by the iOS app and any
other client integrations. The FastAPI backend is the source of truth.

## OpenAPI spec
- `shared/openapi.json` is the latest generated spec.
- `shared/openapi.<YYYY-MM-DD>.json` is a dated snapshot created each time the export runs.

The iOS app should rely on `shared/openapi.json` for client generation and to keep
request/response shapes in sync with the backend.

## Regenerate the contract
From the repo root:
```bash
python backend/scripts/export_openapi.py
```

If you use the backend virtual environment:
```bash
backend/.venv/Scripts/python.exe backend/scripts/export_openapi.py
```

The export script does not require the server to be running.

## Samples
`shared/samples/` includes example request/response JSON for the key endpoints,
including representative error responses, to help client development and testing.
