from datetime import datetime, time, timedelta

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from config import get_settings
from crud import EventDAO
from database import get_db, init_db
from llm_engine import parse_user_intent
from models import (
    EventMutationResponse,
    EventsQueryResponse,
    EventUpdateRequest,
    IntentParseRequest,
    IntentParseResponse,
)


app = FastAPI(title="SyncFlow AI Backend MVP", version="0.1.0")
settings = get_settings()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    init_db()


@app.get("/")
def root() -> dict[str, object]:
    return {
        "service": "SyncFlow AI Backend MVP",
        "status": "running",
        "docs": "/docs",
        "health": "/health",
        "routes": [
            "/api/v1/intent/parse",
            "/api/v1/events",
            "/api/v1/runtime/status",
        ],
    }


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/runtime/status")
def runtime_status() -> dict[str, bool]:
    return {
        "mock_mode": settings.syncflow_mock_llm,
    }


@app.post("/api/v1/intent/parse", response_model=IntentParseResponse)
def parse_and_execute_intent(
    payload: IntentParseRequest,
    db: Session = Depends(get_db),
    api_key: str | None = Header(default=None, alias="X-API-Key"),
    api_base_url: str | None = Header(default=None, alias="X-API-Base-Url"),
    api_model: str | None = Header(default=None, alias="X-API-Model"),
    default_duration: str | None = Header(default=None, alias="X-Default-Duration"),
) -> IntentParseResponse:
    dao = EventDAO(db)

    try:
        parsed_duration = int(default_duration) if default_duration else None
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="X-Default-Duration 必须是整数") from exc

    try:
        parsed_intent = parse_user_intent(
            payload.text,
            api_key=api_key,
            base_url=api_base_url,
            model_name=api_model,
            default_duration_minutes=parsed_duration,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"意图解析失败: {exc}") from exc

    affected_events = []
    for action in parsed_intent.actions:
        if action.action_type == "add":
            affected_events.append(dao.create_event(settings.default_user_id, action))
        elif action.action_type == "delete":
            affected_events.extend(dao.soft_delete_events(settings.default_user_id, action))
        elif action.action_type == "update":
            affected_events.extend(dao.update_events(settings.default_user_id, action))

    return IntentParseResponse(
        success=True,
        message="意图解析并执行成功",
        parsed_intent=parsed_intent,
        affected_events=affected_events,
    )


@app.get("/api/v1/events", response_model=EventsQueryResponse)
def get_events(
    range_type: str = Query("today", description="查询范围，可选 today 或 week"),
    start_date: datetime | None = Query(None, description="自定义查询开始时间，ISO 8601 格式"),
    end_date: datetime | None = Query(None, description="自定义查询结束时间，ISO 8601 格式"),
    db: Session = Depends(get_db),
) -> EventsQueryResponse:
    if (start_date is None) ^ (end_date is None):
        raise HTTPException(status_code=400, detail="start_date 和 end_date 必须同时传入")

    now = datetime.now()
    if start_date is None and end_date is None:
        if range_type not in {"today", "week"}:
            raise HTTPException(status_code=400, detail="range_type 仅支持 today 或 week")

        if range_type == "today":
            normalized_start = datetime.combine(now.date(), time.min)
            normalized_end = datetime.combine(now.date(), time.max)
        else:
            week_start = now.date() - timedelta(days=now.weekday())
            week_end = week_start + timedelta(days=6)
            normalized_start = datetime.combine(week_start, time.min)
            normalized_end = datetime.combine(week_end, time.max)
    else:
        if start_date > end_date:
            raise HTTPException(status_code=400, detail="start_date 不能晚于 end_date")

        normalized_start = datetime.combine(start_date.date(), time.min) if start_date.time() == time.min else start_date
        normalized_end = datetime.combine(end_date.date(), time.max) if end_date.time() == time.min else end_date

    dao = EventDAO(db)
    events = dao.list_events(settings.default_user_id, normalized_start, normalized_end)
    return EventsQueryResponse(success=True, count=len(events), events=events)


@app.patch("/api/v1/events/{event_id}", response_model=EventMutationResponse)
def update_event(
    event_id: int,
    payload: EventUpdateRequest,
    db: Session = Depends(get_db),
) -> EventMutationResponse:
    dao = EventDAO(db)
    event = dao.update_event_by_id(
        settings.default_user_id,
        event_id,
        title=payload.title,
        start_time=payload.start_time,
        duration_minutes=payload.duration_minutes,
        target_keyword=payload.target_keyword,
    )
    if event is None:
        raise HTTPException(status_code=404, detail="事件不存在或已删除")

    return EventMutationResponse(success=True, message="事件更新成功", event=event)


@app.delete("/api/v1/events/{event_id}", response_model=EventMutationResponse)
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
) -> EventMutationResponse:
    dao = EventDAO(db)
    event = dao.soft_delete_event_by_id(settings.default_user_id, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="事件不存在或已删除")

    return EventMutationResponse(success=True, message="事件删除成功", event=event)
