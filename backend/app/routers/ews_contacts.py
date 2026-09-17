from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import get_current_session
from app.schemas.ews import ContactResponse
from app.services.ews_runtime import run_ews
from app.services.ews_service import EwsConnectionError, ews_service
from app.services.session_service import SessionContext

router = APIRouter()


@router.get("", response_model=list[ContactResponse])
async def contacts(
    limit: int = Query(default=100, ge=1, le=500),
    search: str = Query(default=""),
    context: SessionContext = Depends(get_current_session),
):
    try:
        items = await run_ews(
            context,
            ews_service.list_contacts,
            limit=limit,
            search=search,
        )
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return [ContactResponse(**item.__dict__) for item in items]
