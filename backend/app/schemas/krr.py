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
    oiv_class: list[CountPoint] = Field(default_factory=list)
    stage: list[CountPoint] = Field(default_factory=list)
    district: list[CountPoint] = Field(default_factory=list)
    program: list[CountPoint] = Field(default_factory=list)
    status: list[CountPoint] = Field(default_factory=list)
    year: list[CountPoint] = Field(default_factory=list)
    activation: list[CountPoint] = Field(default_factory=list)


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


class KrrWorkPage(BaseModel):
    snapshot_date: date | None = None
    total: int
    limit: int
    offset: int
    items: list[KrrWorkSummary]
