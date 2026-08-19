import asyncio
import json
import logging

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status

from app.config import settings
from app.services.ews_notification_service import ews_notification_service
from app.services.notification_hub import notification_hub
from app.services.session_service import session_service

router = APIRouter()
logger = logging.getLogger(__name__)


@router.websocket("/ws")
async def notifications_websocket(
    websocket: WebSocket,
    token: str = Query(default=""),
):
    if not token.strip():
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    context = session_service.get_session(token)
    if context is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    token_hash = context.token_hash
    await notification_hub.connect(token_hash, websocket)
    ews_notification_service.ensure_worker(context)

    await websocket.send_text(
        json.dumps(
            {
                "event": "connected",
                "data": {
                    "email": context.email,
                    "mode": settings.ews_notification_mode,
                },
            }
        )
    )

    try:
        while True:
            message = await websocket.receive_text()
            if message.strip().lower() == "ping":
                await websocket.send_text(json.dumps({"event": "ping"}))
    except WebSocketDisconnect:
        logger.debug("Notification websocket disconnected for %s", context.email)
    except Exception:
        logger.warning("Notification websocket error", exc_info=True)
    finally:
        await notification_hub.disconnect(token_hash, websocket)
        ews_notification_service.release_worker(token_hash)
