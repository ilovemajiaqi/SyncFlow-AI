from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(100), default="default_user", index=True)
    title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=60, nullable=False)
    target_keyword: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[int] = mapped_column(Integer, default=1, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)


class ActionItem(BaseModel):
    action_type: Literal["add", "delete", "update"]
    event_title: str | None = None
    target_keyword: str | None = None
    start_time: datetime | None = None
    duration_minutes: int = Field(default=60, ge=1)


class ParsedIntent(BaseModel):
    intent: Literal["schedule_update"]
    actions: list[ActionItem]


class IntentParseRequest(BaseModel):
    text: str = Field(min_length=1, description="用户输入的自然语言文本")


class EventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    title: str | None
    start_time: datetime
    duration_minutes: int
    target_keyword: str | None
    status: int
    created_at: datetime


class IntentParseResponse(BaseModel):
    success: bool
    message: str
    parsed_intent: ParsedIntent
    affected_events: list[EventRead]


class EventsQueryResponse(BaseModel):
    success: bool
    count: int
    events: list[EventRead]


class EventUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1)
    start_time: datetime | None = None
    duration_minutes: int | None = Field(default=None, ge=1)
    target_keyword: str | None = None


class EventMutationResponse(BaseModel):
    success: bool
    message: str
    event: EventRead
