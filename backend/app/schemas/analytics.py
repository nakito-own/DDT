from datetime import datetime

from pydantic import BaseModel, Field


class CountPoint(BaseModel):
    label: str
    value: int


class AnalyticsKpis(BaseModel):
    total: int
    assigned: int = 0
    in_progress: int = 0
    waiting_customer: int = 0
    completed: int = 0
    open: int = 0
    resolved: int = 0
    unresolved: int = 0
    user_confirmed: int = 0
    avg_close_days: float | None = None
    sheet_total: int | None = None
    sheet_waiting_left: int | None = None


class AnalyticsSeries(BaseModel):
    status: list[CountPoint] = Field(default_factory=list)
    type: list[CountPoint] = Field(default_factory=list)
    block: list[CountPoint] = Field(default_factory=list)
    category: list[CountPoint] = Field(default_factory=list)
    topics: list[CountPoint] = Field(default_factory=list)
    created_weekly: list[CountPoint] = Field(default_factory=list)


class AnalyticsColumnOption(BaseModel):
    key: str
    label: str
    value: int


class AnalyticsColumn(BaseModel):
    key: str
    label: str
    kind: str
    options: list[AnalyticsColumnOption] = Field(default_factory=list)


class AnalyticsTicket(BaseModel):
    number: str | None = None
    ticket_id: str
    created_at: str | None = None
    closed_at: str | None = None
    subject: str | None = None
    type: str | None = None
    block: str | None = None
    category: str | None = None
    status: str | None = None
    status_4me: str | None = None
    resolved: bool | None = None
    user_confirmed: bool | None = None
    status_bucket: str | None = None
    topic: str | None = None
    fields: dict[str, str] = Field(default_factory=dict)
    dates: dict[str, str] = Field(default_factory=dict)


class AnalyticsDashboardResponse(BaseModel):
    spreadsheet_id: str
    sheet_name: str
    fetched_at: datetime
    kpis: AnalyticsKpis
    series: AnalyticsSeries
    recent: list[AnalyticsTicket] = Field(default_factory=list)
    applications: list[AnalyticsTicket] = Field(default_factory=list)
    columns: list[AnalyticsColumn] = Field(default_factory=list)


class AnalyticsApplicationsResponse(BaseModel):
    spreadsheet_id: str
    sheet_name: str
    fetched_at: datetime
    total: int
    applications: list[AnalyticsTicket]
