import asyncio
import json
import logging
from dataclasses import dataclass, field

from fastapi import WebSocket

logger = logging.getLogger(__name__)


@dataclass
class _SessionConnections:
    websockets: set[WebSocket] = field(default_factory=set)


class NotificationHub:
    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._sessions: dict[str, _SessionConnections] = {}
        self._loop: asyncio.AbstractEventLoop | None = None

    def set_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    async def connect(self, token_hash: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            bucket = self._sessions.setdefault(token_hash, _SessionConnections())
            bucket.websockets.add(websocket)

    async def disconnect(self, token_hash: str, websocket: WebSocket) -> None:
        async with self._lock:
            bucket = self._sessions.get(token_hash)
            if bucket is None:
                return
            bucket.websockets.discard(websocket)
            if not bucket.websockets:
                self._sessions.pop(token_hash, None)

    def has_connections(self, token_hash: str) -> bool:
        bucket = self._sessions.get(token_hash)
        return bool(bucket and bucket.websockets)

    async def broadcast_json(self, token_hash: str, payload: dict) -> None:
        message = json.dumps(payload, default=str)
        async with self._lock:
            bucket = self._sessions.get(token_hash)
            if bucket is None:
                return
            targets = list(bucket.websockets)

        stale: list[WebSocket] = []
        for websocket in targets:
            try:
                await websocket.send_text(message)
            except Exception:
                logger.debug("Removing stale notification websocket", exc_info=True)
                stale.append(websocket)

        if stale:
            async with self._lock:
                bucket = self._sessions.get(token_hash)
                if bucket is None:
                    return
                for websocket in stale:
                    bucket.websockets.discard(websocket)
                if not bucket.websockets:
                    self._sessions.pop(token_hash, None)

    def broadcast_json_threadsafe(self, token_hash: str, payload: dict) -> None:
        if self._loop is None:
            logger.warning("Notification hub loop is not initialized")
            return
        asyncio.run_coroutine_threadsafe(
            self.broadcast_json(token_hash, payload),
            self._loop,
        )


notification_hub = NotificationHub()
