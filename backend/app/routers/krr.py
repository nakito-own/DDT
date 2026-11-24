from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse

from app.dependencies import get_current_session
from app.schemas.analytics import AnalyticsQueryRequest
from app.schemas.krr import (
    KrrDashboardResponse,
    KrrIssuePage,
    KrrRelayAbort,
    KrrRelayBegin,
    KrrRelayFinish,
    KrrRelayPage,
    KrrRelayProgress,
    KrrSyncStatus,
    KrrWorkPage,
)
from app.services.analytics_queries import AnalyticsFilterSpec
from app.services.dtw_client import DtwError
from app.services.dashboard_cache import DashboardBusyError, DashboardTimeoutError
from app.services.krr_dashboard_service import krr_dashboard_service
from app.services.krr_dataset_service import (
    KrrRelayError,
    KrrSyncInProgressError,
    krr_dataset_service,
)
from app.services.session_service import SessionContext

router = APIRouter()


def _dtw_error(exc: DtwError) -> HTTPException:
    return HTTPException(status_code=exc.status_code, detail=str(exc))


def _relay_error(exc: KrrRelayError | KrrSyncInProgressError) -> HTTPException:
    code = exc.status_code if isinstance(exc, KrrRelayError) else status.HTTP_409_CONFLICT
    return HTTPException(status_code=code, detail=str(exc))


@router.post("/sync", response_model=KrrSyncStatus)
def start_krr_sync(
    force: bool = Query(default=False),
    _context: SessionContext = Depends(get_current_session),
):
    try:
        payload, started = krr_dataset_service.start_sync(force=force)
    except KrrSyncInProgressError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except DtwError as exc:
        raise _dtw_error(exc) from exc
    # A finished snapshot for today is returned as-is. The API is not called again.
    code = status.HTTP_202_ACCEPTED if started else status.HTTP_200_OK
    return JSONResponse(
        status_code=code,
        content=jsonable_encoder(KrrSyncStatus.model_validate(payload)),
    )


@router.post("/sync/begin", response_model=KrrRelayBegin)
def begin_krr_relay(
    response: Response,
    force: bool = Query(default=False),
    _context: SessionContext = Depends(get_current_session),
):
    # The body carries the DTW password. Browsers must not cache it.
    response.headers["Cache-Control"] = "no-store"
    try:
        return krr_dataset_service.begin_client_sync(force=force)
    except (KrrRelayError, KrrSyncInProgressError) as exc:
        raise _relay_error(exc) from exc
    except DtwError as exc:
        raise _dtw_error(exc) from exc


@router.post("/sync/page", response_model=KrrRelayProgress)
def accept_krr_relay_page(
    body: KrrRelayPage,
    _context: SessionContext = Depends(get_current_session),
):
    try:
        return krr_dataset_service.accept_client_page(
            sync_id=body.sync_id,
            name=body.name,
            total_count=body.total_count,
            rows=body.rows,
            payload=body.payload,
            offset=body.offset,
            page_start=body.page_start,
            done=body.done,
        )
    except KrrRelayError as exc:
        raise _relay_error(exc) from exc


@router.post("/sync/finish", response_model=KrrSyncStatus)
def finish_krr_relay(
    body: KrrRelayFinish,
    _context: SessionContext = Depends(get_current_session),
):
    try:
        return krr_dataset_service.finish_client_sync(body.sync_id)
    except KrrRelayError as exc:
        raise _relay_error(exc) from exc


@router.post("/sync/abort")
def abort_krr_relay(
    body: KrrRelayAbort,
    _context: SessionContext = Depends(get_current_session),
):
    try:
        krr_dataset_service.abort_client_sync(body.sync_id, body.message)
    except KrrRelayError as exc:
        raise _relay_error(exc) from exc
    return {"status": "failed"}


@router.post("/dashboard", response_model=KrrDashboardResponse)
def query_krr_dashboard(
    body: AnalyticsQueryRequest,
    _context: SessionContext = Depends(get_current_session),
):
    spec = AnalyticsFilterSpec(
        date_column=body.date_column,
        period_start=body.period_start,
        period_end=body.period_end,
        selected=body.selected,
        queries=body.queries,
        exclude_weekends=body.exclude_weekends,
    )
    try:
        return krr_dashboard_service.query(spec, table_limit=body.table_limit)
    except DashboardBusyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except DashboardTimeoutError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc


@router.post("/issues", response_model=KrrIssuePage)
def query_krr_issues(
    body: AnalyticsQueryRequest,
    issue: str = Query(min_length=1, max_length=300),
    _context: SessionContext = Depends(get_current_session),
):
    spec = AnalyticsFilterSpec(
        date_column=body.date_column,
        period_start=body.period_start,
        period_end=body.period_end,
        selected=body.selected,
        queries=body.queries,
        exclude_weekends=body.exclude_weekends,
    )
    try:
        return krr_dashboard_service.issues(spec, issue, body.table_limit)
    except DashboardBusyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except DashboardTimeoutError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc


@router.get("/sync", response_model=KrrSyncStatus)
def krr_sync_status(_context: SessionContext = Depends(get_current_session)):
    return krr_dataset_service.status()


@router.get("/works", response_model=KrrWorkPage)
def list_krr_works(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    snapshot: Literal["today", "yesterday"] = "today",
    work_year: int | None = None,
    stage: str | None = Query(default=None, max_length=128),
    adm_district: str | None = Query(default=None, max_length=64),
    district: str | None = Query(default=None, max_length=128),
    dk: bool | None = None,
    q: str | None = Query(default=None, max_length=200),
    _context: SessionContext = Depends(get_current_session),
):
    return krr_dataset_service.list_works(
        limit=limit,
        offset=offset,
        snapshot=snapshot,
        work_year=work_year,
        stage=stage,
        adm_district=adm_district,
        district=district,
        dk=dk,
        query=q,
    )


@router.get("/works/{id_unique}")
def get_krr_work(
    id_unique: int,
    snapshot: Literal["today", "yesterday"] = "today",
    _context: SessionContext = Depends(get_current_session),
):
    row = krr_dataset_service.get_work(id_unique, snapshot=snapshot)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Версия работы не найдена",
        )
    return row
