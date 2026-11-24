import asyncio

from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import get_current_session
from app.schemas.task_analytics import TaskAnalyticsQueryRequest, TaskAnalyticsQueryResponse
from app.services.analytics_queries import AnalyticsFilterSpec
from app.services.dashboard_cache import DashboardBusyError, DashboardTimeoutError
from app.services.session_service import SessionContext
from app.services.task_analytics_service import task_analytics_service

router = APIRouter()


@router.post("/query", response_model=TaskAnalyticsQueryResponse)
async def query_task_dashboard(
    body: TaskAnalyticsQueryRequest,
    context: SessionContext = Depends(get_current_session),
):
    scope = task_analytics_service.resolve_scope(
        scope=body.scope,
        user_id=context.user_id,
        space_id=body.space_id,
    )
    spec = AnalyticsFilterSpec(
        date_column=body.date_column,
        period_start=body.period_start,
        period_end=body.period_end,
        selected=body.selected,
        queries=body.queries,
        exclude_weekends=body.exclude_weekends,
    )
    try:
        payload = await asyncio.to_thread(
            task_analytics_service.query,
            scope,
            spec,
            table_limit=body.table_limit,
            table_offset=body.table_offset,
        )
    except (DashboardBusyError, DashboardTimeoutError) as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    return payload
