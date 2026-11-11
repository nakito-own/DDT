import logging
import threading

from app.config import settings

logger = logging.getLogger(__name__)


class EwsKeepaliveService:
    """Re-authenticates live Exchange/OWA connections before their cookies die."""

    def __init__(self) -> None:
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._loop,
            name="ews-keepalive",
            daemon=True,
        )
        self._thread.start()
        logger.info(
            "EWS keepalive started, interval=%sh",
            settings.ews_refresh_interval_hours,
        )

    def stop(self) -> None:
        self._stop.set()
        thread = self._thread
        if thread is not None:
            thread.join(timeout=5)
        self._thread = None

    def _loop(self) -> None:
        tick_seconds = max(60, settings.ews_refresh_check_seconds)
        while not self._stop.wait(tick_seconds):
            try:
                from app.services.session_service import session_service

                session_service.refresh_live_exchange_sessions()
            except Exception:
                logger.exception("EWS keepalive cycle failed")


ews_keepalive_service = EwsKeepaliveService()
