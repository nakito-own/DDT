from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


NotificationCategory = Literal[
    "new_mail",
    "mail_updated",
    "calendar_updated",
    "system",
]


class NotificationPayload(BaseModel):
    id: str
    category: NotificationCategory
    title: str
    body: str
    timestamp: datetime
    item_id: str | None = None
    source: Literal["ews_inbox", "ews_calendar", "system"] = "system"


class WsServerMessage(BaseModel):
    event: Literal["notification", "ping", "connected", "error"]
    data: NotificationPayload | dict | None = None
