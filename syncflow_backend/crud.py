from datetime import datetime, timedelta

from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from models import ActionItem, Event


class EventDAO:
    def __init__(self, db: Session):
        self.db = db

    def create_event(self, user_id: str, action: ActionItem) -> Event:
        if action.start_time is None:
            raise ValueError("新增事件必须包含 start_time")

        event = Event(
            user_id=user_id,
            title=action.event_title,
            start_time=action.start_time,
            duration_minutes=action.duration_minutes or 60,
            target_keyword=action.target_keyword,
            status=1,
        )
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event

    def soft_delete_events(self, user_id: str, action: ActionItem) -> list[Event]:
        stmt = select(Event).where(Event.user_id == user_id, Event.status == 1)

        filters = []
        if action.target_keyword:
            keyword = f"%{action.target_keyword}%"
            filters.append(
                or_(
                    Event.title.ilike(keyword),
                    Event.target_keyword.ilike(keyword),
                )
            )

        if action.start_time:
            start_window = action.start_time - timedelta(hours=2)
            end_window = action.start_time + timedelta(hours=2)
            filters.append(and_(Event.start_time >= start_window, Event.start_time <= end_window))

        if filters:
            stmt = stmt.where(or_(*filters))
        else:
            return []

        matched_events = list(self.db.scalars(stmt).all())
        for event in matched_events:
            event.status = 0

        self.db.commit()
        return matched_events

    def update_events(self, user_id: str, action: ActionItem) -> list[Event]:
        stmt = select(Event).where(Event.user_id == user_id, Event.status == 1)
        if action.target_keyword:
            keyword = f"%{action.target_keyword}%"
            stmt = stmt.where(
                or_(
                    Event.title.ilike(keyword),
                    Event.target_keyword.ilike(keyword),
                )
            )
        elif action.start_time:
            start_window = action.start_time - timedelta(hours=2)
            end_window = action.start_time + timedelta(hours=2)
            stmt = stmt.where(and_(Event.start_time >= start_window, Event.start_time <= end_window))
        else:
            return []

        matched_events = list(self.db.scalars(stmt).all())
        for event in matched_events:
            if action.event_title is not None:
                event.title = action.event_title
            if action.start_time is not None:
                event.start_time = action.start_time
            if action.duration_minutes is not None:
                event.duration_minutes = action.duration_minutes
            if action.target_keyword is not None:
                event.target_keyword = action.target_keyword

        self.db.commit()
        for event in matched_events:
            self.db.refresh(event)
        return matched_events

    def list_events(self, user_id: str, start_date: datetime, end_date: datetime) -> list[Event]:
        stmt = (
            select(Event)
            .where(
                Event.user_id == user_id,
                Event.status == 1,
                Event.start_time >= start_date,
                Event.start_time <= end_date,
            )
            .order_by(Event.start_time.asc())
        )
        return list(self.db.scalars(stmt).all())

    def get_event_by_id(self, user_id: str, event_id: int) -> Event | None:
        stmt = select(Event).where(Event.id == event_id, Event.user_id == user_id, Event.status == 1)
        return self.db.scalar(stmt)

    def update_event_by_id(
        self,
        user_id: str,
        event_id: int,
        *,
        title: str | None = None,
        start_time: datetime | None = None,
        duration_minutes: int | None = None,
        target_keyword: str | None = None,
    ) -> Event | None:
        event = self.get_event_by_id(user_id, event_id)
        if event is None:
            return None

        if title is not None:
            event.title = title
        if start_time is not None:
            event.start_time = start_time
        if duration_minutes is not None:
            event.duration_minutes = duration_minutes
        if target_keyword is not None:
            event.target_keyword = target_keyword

        self.db.commit()
        self.db.refresh(event)
        return event

    def soft_delete_event_by_id(self, user_id: str, event_id: int) -> Event | None:
        event = self.get_event_by_id(user_id, event_id)
        if event is None:
            return None

        event.status = 0
        self.db.commit()
        self.db.refresh(event)
        return event
