from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import get_current_session
from app.schemas.ews import (
    CalendarEventResponse,
    CalendarEventResponseRequest,
    CreateCalendarEventRequest,
)
from app.services.ews_service import EwsConnectionError, EwsNotFoundError, ews_service
from app.services.session_service import SessionContext, session_service

router = APIRouter()


@router.get("/events", response_model=list[CalendarEventResponse])
async def calendar_events(
    start: datetime | None = Query(default=None),
    end: datetime | None = Query(default=None),
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        events = ews_service.list_calendar_events(account, start=start, end=end)
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to fetch calendar events from Exchange",
        ) from exc

    return [CalendarEventResponse(**event.__dict__) for event in events]


@router.post("/events", response_model=CalendarEventResponse, status_code=status.HTTP_201_CREATED)
async def create_calendar_event(
    payload: CreateCalendarEventRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        event = ews_service.create_calendar_event(
            account=account,
            subject=payload.subject,
            start=payload.start,
            end=payload.end,
            location=payload.location,
            body=payload.body,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to create calendar event via Exchange",
        ) from exc

    return CalendarEventResponse(**event.__dict__)


@router.post(
    "/events/{event_id:path}/response",
    response_model=CalendarEventResponse,
)
async def respond_to_calendar_event(
    event_id: str,
    payload: CalendarEventResponseRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        event = ews_service.respond_to_calendar_event(
            account=account,
            event_id=event_id,
            response=payload.response,
        )
    except EwsNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to respond to calendar event via Exchange",
        ) from exc

    return CalendarEventResponse(**event.__dict__)
