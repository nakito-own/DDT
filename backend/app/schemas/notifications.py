from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


NotificationCategory = Literal[
    "new_mail",
    "mail_updated",
    "calendar_updated",
    "task_assigned",
    "task_updated",
    "system",
]


class NotificationPayload(BaseModel):
    id: str
    category: NotificationCategory
    title: str
    body: str
    timestamp: datetime
    item_id: str | None = None
    source: Literal["ews_inbox", "ews_calendar", "tasks", "system"] = "system"
    target_kind: Literal["mail", "calendar", "task"] | None = None
    task_key: str | None = None
    space_key: str | None = None
    focus_at: datetime | None = None
    match_subject: str | None = None
    silent: bool = False


class WsServerMessage(BaseModel):
    event: Literal["notification", "ping", "connected", "error"]
    data: NotificationPayload | dict | None = None
