from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import Response

from app.dependencies import get_current_session
from app.services.ews_runtime import EwsOverloadedError, run_blocking
from app.services.owa_transport import OwaTransportError, owa_transport
from app.services.session_service import SessionContext

router = APIRouter()

_MAX_BODY_BYTES = 2_000_000


@router.post("/service")
async def forward_owa_service(
    request: Request,
    action: str = Query(min_length=1, max_length=64),
    context: SessionContext = Depends(get_current_session),
):
    body = await request.body()
    if len(body) > _MAX_BODY_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="OWA request is too large",
        )
    try:
        status_code, content_type, payload = await run_blocking(
            owa_transport.forward_json,
            context,
            action,
            body,
        )
    except OwaTransportError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    except EwsOverloadedError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc

    return Response(content=payload, status_code=status_code, media_type=content_type)
