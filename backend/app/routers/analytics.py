import asyncio

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import get_current_session
from app.schemas.analytics import (
    AnalyticsApplicationsResponse,
    AnalyticsDashboardResponse,
)
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


@router.get("/dashboard", response_model=AnalyticsDashboardResponse)
async def get_dashboard(
    refresh: bool = Query(default=False),
    _context: SessionContext = Depends(get_current_session),
):
    try:
        payload = await asyncio.to_thread(
            analytics_service.get_dashboard,
            refresh=refresh,
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
