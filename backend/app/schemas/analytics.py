from datetime import date, datetime

from pydantic import BaseModel, Field


class CountPoint(BaseModel):
    label: str
    value: int


class HoursPoint(BaseModel):
    label: str
    hours: float


class AnalyticsColumnOption(BaseModel):
    key: str
    label: str
    value: int


class AnalyticsColumn(BaseModel):
    key: str
    label: str
    kind: str
    computed: bool = False
    options: list[AnalyticsColumnOption] = Field(default_factory=list)


class AnalyticsDateBounds(BaseModel):
    min: date
    max: date


class AnalyticsQueryRequest(BaseModel):
    date_column: str | None = None
    period_start: date | None = None
    period_end: date | None = None
    selected: dict[str, list[str]] = Field(default_factory=dict)
    queries: dict[str, str] = Field(default_factory=dict)
    table_limit: int = Field(default=200, ge=1, le=1000)
    table_offset: int = Field(default=0, ge=0)
    refresh: bool = False
    allow_stale: bool = False


class AnalyticsKpi(BaseModel):
    total: int
    open: int
    closed: int
    sla_ok: int
    sla_known: int
    confirmed: int
    overdue_open: int
    median_resolution_hours: float | None = None
    median_reaction_hours: float | None = None
    reaction_count: int
    errors: int
    waiting_open: int
    top_waiting_oiv: str | None = None
    top_waiting_oiv_hours: float | None = None
    top_waiting_oiv_open: int = 0


class AnalyticsTrend(BaseModel):
    labels: list[str] = Field(default_factory=list)
    created: list[int] = Field(default_factory=list)
    closed: list[int] = Field(default_factory=list)


class AnalyticsDailyBucket(BaseModel):
    day: date
    created: int
    closed: int
    avg_reaction_hours: float | None = None


class AnalyticsStatusByCategory(BaseModel):
    categories: list[str] = Field(default_factory=list)
    closed: list[int] = Field(default_factory=list)
    in_progress: list[int] = Field(default_factory=list)
    waiting: list[int] = Field(default_factory=list)


class AnalyticsSolved(BaseModel):
    labels: list[str] = Field(default_factory=list)
    solved: list[int] = Field(default_factory=list)
    confirmed: list[int] = Field(default_factory=list)


class AnalyticsCharts(BaseModel):
    trend: dict[str, AnalyticsTrend]
    type: list[CountPoint]
    block: list[CountPoint]
    oiv: list[CountPoint]
    module: list[CountPoint]
    problem_category: list[CountPoint]
    status_group: list[CountPoint]
    error_side: list[CountPoint]
    oiv_waiting: list[HoursPoint]
    daily_detail: list[AnalyticsDailyBucket]
    status_by_category: AnalyticsStatusByCategory
    solved: AnalyticsSolved


class AnalyticsGroupRow(BaseModel):
    name: str
    count: int
    share: float
    avg_resolution_hours: float | None = None
    avg_reaction_hours: float | None = None
    closed: int
    in_progress: int
    waiting: int
    error_side: str | None = None
    example_ids: list[str]


class AnalyticsOivWaitingRow(BaseModel):
    name: str
    episode_count: int
    open_waiting: int
    avg_waiting_hours: float | None = None
    median_waiting_hours: float | None = None
    max_waiting_hours: float | None = None
    example_ids: list[str]


class AnalyticsCrossMatrix(BaseModel):
    rows: list[str] = Field(default_factory=list)
    cols: list[str] = Field(default_factory=list)
    values: list[list[int]] = Field(default_factory=list)


class AnalyticsSummary(BaseModel):
    category: list[AnalyticsGroupRow]
    block: list[AnalyticsGroupRow]
    error_side: list[AnalyticsGroupRow]
    oiv_waiting: list[AnalyticsOivWaitingRow]
    cross_matrix: AnalyticsCrossMatrix


class AnalyticsTableRow(BaseModel):
    id: str
    permalink: str | None = None
    state: str
    state_label: str
    type: str | None = None
    block: str | None = None
    problem_category: str | None = None
    subject: str | None = None
    member: str | None = None
    requested_by: str | None = None
    oiv: str | None = None
    created_at: datetime | None = None
    completed_at: datetime | None = None
    resolution_hours: float | None = None
    reaction_hours: float | None = None
    error_side: str | None = None
    sla_met: bool | None = None
    is_overdue: bool = False


class AnalyticsRecordsPage(BaseModel):
    items: list[AnalyticsTableRow]
    total: int
    limit: int
    offset: int


class AnalyticsQueryResponse(BaseModel):
    spreadsheet_id: str
    sheet_name: str
    fetched_at: datetime
    itsm_base_url: str
    total_count: int
    filtered_count: int
    date_column: str
    columns: list[AnalyticsColumn]
    date_bounds: dict[str, AnalyticsDateBounds]
    kpi: AnalyticsKpi
    charts: AnalyticsCharts
    summary: AnalyticsSummary
    records: AnalyticsRecordsPage


class AnalyticsTicket(BaseModel):
    id: str
    number: str | None = None
    permalink: str | None = None
    state: str
    status: str | None = None
    status_4me: str | None = None
    status_group: str
    type: str | None = None
    block: str | None = None
    problem_category: str | None = None
    subject: str | None = None
    solved: str | None = None
    user_confirmed: str | None = None
    member: str | None = None
    requested_by: str | None = None
    oiv: str | None = None
    organization: str | None = None
    error_side: str
    module: str
    resource: str | None = None
    created_at: datetime | None = None
    work_taken_at: datetime | None = None
    completed_at: datetime | None = None
    sla_target: datetime | None = None
    resolution_hours: float | None = None
    reaction_hours: float | None = None
    sla_met: bool | None = None
    comment_count: int = 0
    waiting_started_at: datetime | None = None
    client_response_hours: float | None = None
    has_waiting_episode: bool = False
    fields: dict[str, str] = Field(default_factory=dict)
    dates: dict[str, date] = Field(default_factory=dict)


class AnalyticsApplicationsResponse(BaseModel):
    spreadsheet_id: str
    sheet_name: str
    fetched_at: datetime
    total: int
    applications: list[AnalyticsTicket]
