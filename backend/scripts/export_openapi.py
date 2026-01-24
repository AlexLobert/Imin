import json
from datetime import datetime, timezone
from pathlib import Path
import sys


def _load_app():
    script_path = Path(__file__).resolve()
    backend_dir = script_path.parents[1]
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))
    from app.main import app  # pylint: disable=import-error

    return app


def export_openapi() -> tuple[Path, Path]:
    app = _load_app()
    spec = app.openapi()

    backend_dir = Path(__file__).resolve().parents[1]
    repo_root = backend_dir.parent
    shared_dir = repo_root / "shared"
    shared_dir.mkdir(parents=True, exist_ok=True)

    openapi_path = shared_dir / "openapi.json"
    snapshot_date = datetime.now(timezone.utc).date().isoformat()
    snapshot_path = shared_dir / f"openapi.{snapshot_date}.json"

    payload = json.dumps(spec, indent=2, sort_keys=True)
    openapi_path.write_text(payload + "\n", encoding="utf-8")
    snapshot_path.write_text(payload + "\n", encoding="utf-8")

    return openapi_path, snapshot_path


if __name__ == "__main__":
    latest_path, dated_path = export_openapi()
    print(f"Wrote {latest_path}")
    print(f"Wrote {dated_path}")
