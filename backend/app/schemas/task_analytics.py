from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.analytics import AnalyticsQueryResponse


class TaskAnalyticsQueryRequest(BaseModel):
    scope: Literal["personal", "space"]
    space_id: int | None = None
    date_column: str | None = None
    period_start: date | None = None
    period_end: date | None = None
    selected: dict[str, list[str]] = Field(default_factory=dict)
    queries: dict[str, str] = Field(default_factory=dict)
    table_limit: int = Field(default=200, ge=1, le=1000)
    table_offset: int = Field(default=0, ge=0)


class TaskAnalyticsQueryResponse(AnalyticsQueryResponse):
    dashboard_kind: Literal["tasks_personal", "tasks_space"] = "tasks_personal"
    space_name: str | None = None
