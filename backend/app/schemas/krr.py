from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

from app.schemas.analytics import AnalyticsColumn, AnalyticsDateBounds, CountPoint


class KrrSnapshotStatus(BaseModel):
    snapshot_date: date
    role: Literal["today", "yesterday"]
    dataset_name: str = ""
    status: str
    total_count: int = 0
    stored_count: int = 0
    error_message: str | None = None
    started_at: datetime | None = None
    finished_at: datetime | None = None


class KrrSyncStatus(BaseModel):
    dataset_id: int
    fetched_from_api: bool = False
    today: KrrSnapshotStatus
    yesterday: KrrSnapshotStatus


class KrrRelayBegin(BaseModel):
    needed: bool
    sync_id: str = ""
    dataset_id: int
    base_url: str = ""
    login: str = ""
    password: str = ""
    page_size: int = 200
    offset_param: str = "offset"
    limit_param: str = "limit"
    today: KrrSnapshotStatus
    yesterday: KrrSnapshotStatus


class KrrRelayPage(BaseModel):
    sync_id: str = Field(min_length=16, max_length=64)
    name: str = Field(default="", max_length=512)
    total_count: int = Field(default=0, ge=0)
    offset: int = Field(default=0, ge=0)
    # First slice of a DTW page. Repeat detection uses only this slice.
    page_start: bool = False
    # Client knows the dataset ended; an upload slice is smaller than a DTW page.
    done: bool = False
    # One slice of a DTW page. The client does not build row objects.
    payload: dict[str, Any] | None = None
    rows: list[dict[str, Any]] = Field(default_factory=list, max_length=500)


class KrrRelayFinish(BaseModel):
    sync_id: str = Field(min_length=16, max_length=64)


class KrrRelayAbort(BaseModel):
    sync_id: str = Field(min_length=16, max_length=64)
    message: str = Field(default="", max_length=2000)


class KrrRelayProgress(BaseModel):
    stored_count: int
    total_count: int
    accepted: int = 0
    row_count: int = 0
    done: bool = False


class KrrWorkSummary(BaseModel):
    id_unique: int
    name_work_version: str | None = None
    id_work: int | None = None
    work_year: int | None = None
    stage: str | None = None
    stage_id: int | None = None
    adm_district: str | None = None
    district: str | None = None
    address: str | None = None
    dk: bool | None = None
    square: float | None = None
    status_id_name: str | None = None
    program: str | None = None
    category_object: str | None = None
    link: str | None = None
    customer: str | None = None
    activation_status: str | None = None
    plan_start_date: date | None = None
    plan_end_date: date | None = None
    fact_start_date: date | None = None
    fact_end_date: date | None = None


class KrrKpi(BaseModel):
    versions: int = 0
    unique_works: int = 0
    oiv_count: int = 0
    balance_holders: int = 0
    delta: int | None = None
    dk_count: int = 0
    last_changed: date | None = None
    fill_percent: float = 0


class KrrTrendSeries(BaseModel):
    day: list[CountPoint] = Field(default_factory=list)
    week: list[CountPoint] = Field(default_factory=list)
    month: list[CountPoint] = Field(default_factory=list)


class KrrCharts(BaseModel):
    created: KrrTrendSeries = Field(default_factory=KrrTrendSeries)
    changed: KrrTrendSeries = Field(default_factory=KrrTrendSeries)
    created_work: KrrTrendSeries = Field(default_factory=KrrTrendSeries)
    changed_work: KrrTrendSeries = Field(default_factory=KrrTrendSeries)
    created_card: KrrTrendSeries = Field(default_factory=KrrTrendSeries)
    changed_card: KrrTrendSeries = Field(default_factory=KrrTrendSeries)
    oiv_class: list[CountPoint] = Field(default_factory=list)
    stage: list[CountPoint] = Field(default_factory=list)
    district: list[CountPoint] = Field(default_factory=list)
    program: list[CountPoint] = Field(default_factory=list)
    status: list[CountPoint] = Field(default_factory=list)
    year: list[CountPoint] = Field(default_factory=list)
    activation: list[CountPoint] = Field(default_factory=list)


class KrrSchedule(BaseModel):
    early: int = 0
    on_time: int = 0
    late: int = 0
    unfinished: int = 0
    incomplete_dates: int = 0
    overdue_open: int = 0
    dated_completed: int = 0
    early_share: float | None = None
    on_time_share: float | None = None
    late_share: float | None = None
    avg_deviation_days: float | None = None
    avg_duration_days: float | None = None


class KrrQualityIndex(BaseModel):
    score: float | None = None
    completeness: float | None = None
    correctness: float | None = None
    consistency: float | None = None
    freshness: float | None = None
    uniqueness: float | None = None
    weights: dict[str, float] = Field(default_factory=dict)


class KrrFieldFill(BaseModel):
    key: str
    label: str
    filled: int = 0
    empty: int = 0
    applicable: int = 0
    percent: float | None = None


class KrrRule(BaseModel):
    code: str
    title: str
    description: str
    count: int = 0
    severity: Literal["critical", "warning", "info"]
    group: str


class KrrAreaRow(BaseModel):
    id_unique: int
    id_work: int | None = None
    name_work_version: str | None = None
    address: str | None = None
    stage: str | None = None
    link: str | None = None


class KrrInsights(BaseModel):
    works: int = 0
    rows_without_work_id: int = 0
    completed: int = 0
    in_progress: int = 0
    cancelled: int = 0
    other_stage: int = 0
    square_sum: float | None = None
    square_avg: float | None = None
    square_known: int = 0
    stage_buckets: list[CountPoint] = Field(default_factory=list)
    oiv: list[CountPoint] = Field(default_factory=list)
    year_versions: list[CountPoint] = Field(default_factory=list)
    year_works: list[CountPoint] = Field(default_factory=list)
    year_square: list[CountPoint] = Field(default_factory=list)
    cancel_reasons: list[CountPoint] = Field(default_factory=list)
    categories: dict[str, list[CountPoint]] = Field(default_factory=dict)
    schedule: KrrSchedule = Field(default_factory=KrrSchedule)
    quality: KrrQualityIndex = Field(default_factory=KrrQualityIndex)
    fields: list[KrrFieldFill] = Field(default_factory=list)
    rules: list[KrrRule] = Field(default_factory=list)
    version_buckets: list[CountPoint] = Field(default_factory=list)
    duplicate_id_unique: int = 0
    repeated_version_works: int = 0
    works_missing_first_version: int | None = None
    multiple_without_archive: int | None = None
    actual_flag_available: bool = False
    freshness: list[CountPoint] = Field(default_factory=list)
    freshness_avg_days: float | None = None
    freshness_known: int = 0
    stale_by_oiv: list[CountPoint] = Field(default_factory=list)
    missing_area_total: int = 0
    missing_area: list[KrrAreaRow] = Field(default_factory=list)
    unavailable: list[str] = Field(default_factory=list)
    snapshot_note: str = ""


class KrrIssueRow(KrrAreaRow):
    problem: str = ""


class KrrIssuePage(BaseModel):
    total: int = 0
    problem: str = ""
    items: list[KrrIssueRow] = Field(default_factory=list)


class KrrDashboardRecords(BaseModel):
    items: list[dict[str, Any]] = Field(default_factory=list)
    total: int = 0
    limit: int = 0
    offset: int = 0


class KrrDashboardResponse(BaseModel):
    snapshot_date: date
    fetched_at: datetime
    title: str = "Версии работ КРР МР"
    total_count: int = 0
    filtered_count: int = 0
    date_column: str
    columns: list[AnalyticsColumn] = Field(default_factory=list)
    date_bounds: dict[str, AnalyticsDateBounds] = Field(default_factory=dict)
    kpi: KrrKpi
    charts: KrrCharts
    records: KrrDashboardRecords
    insights: KrrInsights = Field(default_factory=KrrInsights)


class KrrWorkPage(BaseModel):
    snapshot_date: date | None = None
    total: int
    limit: int
    offset: int
    items: list[KrrWorkSummary]
