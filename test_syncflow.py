import os
import sys
from pathlib import Path

from fastapi.testclient import TestClient


PROJECT_ROOT = Path(__file__).resolve().parent / "syncflow_backend"
sys.path.insert(0, str(PROJECT_ROOT))

os.environ["SYNCFLOW_MOCK_LLM"] = "true"
os.environ["DATABASE_URL"] = "sqlite:///./test_syncflow.db"

from database import init_db  # noqa: E402
from main import app  # noqa: E402


def run_smoke_test() -> None:
    init_db()
    client = TestClient(app)

    parse_response = client.post(
        "/api/v1/intent/parse",
        json={"text": "明天下午3点开会，取消晚上的打球"},
    )
    assert parse_response.status_code == 200, parse_response.text

    default_events_response = client.get("/api/v1/events")
    assert default_events_response.status_code == 200, default_events_response.text

    week_events_response = client.get(
        "/api/v1/events",
        params={"range_type": "week"},
    )
    assert week_events_response.status_code == 200, week_events_response.text

    custom_events_response = client.get(
        "/api/v1/events",
        params={
            "start_date": "2026-03-28T00:00:00",
            "end_date": "2026-04-05T23:59:59",
        },
    )
    assert custom_events_response.status_code == 200, custom_events_response.text

    print("POST /api/v1/intent/parse =>", parse_response.json())
    print("GET /api/v1/events (default today) =>", default_events_response.json())
    print("GET /api/v1/events?range_type=week =>", week_events_response.json())
    print("GET /api/v1/events custom range =>", custom_events_response.json())


if __name__ == "__main__":
    run_smoke_test()

