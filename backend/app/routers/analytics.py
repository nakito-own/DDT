import asyncio

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import get_current_session
from app.schemas.analytics import (
    AnalyticsApplicationsResponse,
    AnalyticsQueryRequest,
    AnalyticsQueryResponse,
)
from app.services.analytics_queries import AnalyticsFilterSpec
from app.services.analytics_service import (
    AnalyticsNotConfiguredError,
    analytics_service,
)
from app.services.google_sheets_client import GoogleSheetsAccessError
from app.services.session_service import SessionContext

router = APIRouter()


def _map_errors(exc: Exception) -> HTTPException:
    if isinstance(exc, AnalyticsNotConfiguredError):
        return HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )
    if isinstance(exc, GoogleSheetsAccessError):
        status_code = (
            status.HTTP_404_NOT_FOUND
            if exc.status_code == 404
            else status.HTTP_502_BAD_GATEWAY
        )
        return HTTPException(status_code=status_code, detail=str(exc))
    raise exc


@router.post("/query", response_model=AnalyticsQueryResponse)
async def query_dashboard(
    body: AnalyticsQueryRequest,
    _context: SessionContext = Depends(get_current_session),
):
    spec = AnalyticsFilterSpec(
        date_column=body.date_column,
        period_start=body.period_start,
        period_end=body.period_end,
        selected=body.selected,
        queries=body.queries,
    )
    try:
        payload = await asyncio.to_thread(
            analytics_service.query,
            spec,
            table_limit=body.table_limit,
            table_offset=body.table_offset,
            refresh=body.refresh,
            allow_stale=body.allow_stale,
        )
    except (AnalyticsNotConfiguredError, GoogleSheetsAccessError) as exc:
        raise _map_errors(exc) from exc
    return payload


@router.get("/applications", response_model=AnalyticsApplicationsResponse)
async def get_applications(
    refresh: bool = Query(default=False),
    _context: SessionContext = Depends(get_current_session),
):
    try:
        payload = await asyncio.to_thread(
            analytics_service.get_applications,
            refresh=refresh,
        )
    except (AnalyticsNotConfiguredError, GoogleSheetsAccessError) as exc:
        raise _map_errors(exc) from exc
    return payload
