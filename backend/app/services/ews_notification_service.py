import logging
import threading
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Literal

from exchangelib import Account
from exchangelib.errors import ErrorSubscriptionNotFound
from exchangelib.properties import StatusEvent

from app.config import settings
from app.services.ews_service import ews_service
from app.services.notification_hub import notification_hub
from app.services.session_service import SessionContext, session_service

logger = logging.getLogger(__name__)

INBOX_EVENT_TYPES = ["NewMailEvent"]
CALENDAR_EVENT_TYPES = ["CreatedEvent", "ModifiedEvent"]


@dataclass
class _WorkerState:
    thread: threading.Thread
    stop_event: threading.Event
    clients: int = 0


class EwsNotificationService:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._workers: dict[str, _WorkerState] = {}

    def ensure_worker(self, context: SessionContext) -> None:
        token_hash = context.token_hash
        with self._lock:
            worker = self._workers.get(token_hash)
            if worker is not None:
                worker.clients += 1
                return

            stop_event = threading.Event()
            thread = threading.Thread(
                target=self._run_worker,
                args=(context.token_hash, stop_event),
                name=f"ews-notify-{token_hash[:8]}",
                daemon=True,
            )
            self._workers[token_hash] = _WorkerState(
                thread=thread,
                stop_event=stop_event,
                clients=1,
            )
            thread.start()
            logger.info("Started EWS notification worker for %s", context.email)

    def release_worker(self, token_hash: str) -> None:
        with self._lock:
            worker = self._workers.get(token_hash)
            if worker is None:
                return
            worker.clients = max(worker.clients - 1, 0)
            if worker.clients > 0:
                return
            worker.stop_event.set()
            self._workers.pop(token_hash, None)
            logger.info("Stopping EWS notification worker for token hash %s", token_hash[:8])

    def stop_for_session(self, token_hash: str) -> None:
        with self._lock:
            worker = self._workers.pop(token_hash, None)
        if worker is None:
            return
        worker.stop_event.set()
        worker.clients = 0

    def shutdown_all(self) -> None:
        with self._lock:
            workers = list(self._workers.values())
            self._workers.clear()
        for worker in workers:
            worker.stop_event.set()

    def _create_worker_account(self, context: SessionContext) -> Account:
        """Dedicated EWS account for the worker thread.

        Must not reuse session_service account cache — exchangelib is not thread-safe.
        """
        account = ews_service.create_account(
            context.username,
            context.password,
            context.email,
        )
        ews_service.verify_account(account)
        return account

    def _run_worker(self, token_hash: str, stop_event: threading.Event) -> None:
        failures = 0
        while not stop_event.is_set():
            if not notification_hub.has_connections(token_hash):
                time.sleep(1)
                continue

            context = session_service.get_session_by_hash(token_hash)
            if context is None:
                logger.info("Session gone, stopping notification worker")
                break

            try:
                if settings.ews_notification_mode == "pull":
                    self._pull_loop(context, stop_event)
                else:
                    self._streaming_loop(context, stop_event)
                failures = 0
            except ErrorSubscriptionNotFound:
                failures += 1
                logger.info(
                    "EWS subscription expired for %s, reconnecting (attempt %s)",
                    context.email,
                    failures,
                )
                stop_event.wait(min(10, failures * 2))
            except Exception:
                failures += 1
                logger.warning(
                    "EWS notification worker error for %s (attempt %s)",
                    context.email,
                    failures,
                    exc_info=True,
                )
                stop_event.wait(min(30, 2 ** min(failures, 4)))

    def _streaming_loop(
        self, context: SessionContext, stop_event: threading.Event
    ) -> None:
        account = self._create_worker_account(context)
        inbox_sub_id = account.inbox.subscribe_to_streaming(
            event_types=INBOX_EVENT_TYPES
        )

        try:
            while not stop_event.is_set() and notification_hub.has_connections(
                context.token_hash
            ):
                for notification in account.inbox.get_streaming_events(
                    inbox_sub_id,
                    connection_timeout=settings.ews_notification_stream_timeout,
                ):
                    if stop_event.is_set():
                        break
                    self._dispatch_notification(
                        context.token_hash,
                        notification.events,
                        source="ews_inbox",
                    )
        finally:
            try:
                account.inbox.unsubscribe(inbox_sub_id)
            except Exception:
                logger.debug(
                    "Failed to unsubscribe streaming subscription",
                    exc_info=True,
                )

    def _pull_loop(self, context: SessionContext, stop_event: threading.Event) -> None:
        account = self._create_worker_account(context)
        inbox_sub_id, inbox_watermark = account.inbox.subscribe_to_pull(
            event_types=INBOX_EVENT_TYPES,
            timeout=settings.ews_notification_pull_timeout,
        )
        calendar_sub_id, calendar_watermark = account.calendar.subscribe_to_pull(
            event_types=CALENDAR_EVENT_TYPES,
            timeout=settings.ews_notification_pull_timeout,
        )

        try:
            while not stop_event.is_set() and notification_hub.has_connections(
                context.token_hash
            ):
                inbox_watermark = self._poll_subscription(
                    account.inbox,
                    inbox_sub_id,
                    inbox_watermark,
                    context.token_hash,
                    source="ews_inbox",
                )
                calendar_watermark = self._poll_subscription(
                    account.calendar,
                    calendar_sub_id,
                    calendar_watermark,
                    context.token_hash,
                    source="ews_calendar",
                )
                stop_event.wait(settings.ews_notification_poll_interval)
        finally:
            for sub_id in (inbox_sub_id, calendar_sub_id):
                try:
                    account.inbox.unsubscribe(sub_id)
                except Exception:
                    logger.debug(
                        "Failed to unsubscribe pull subscription",
                        exc_info=True,
                    )

    def _poll_subscription(
        self,
        folder: Any,
        subscription_id: str,
        watermark: str,
        token_hash: str,
        *,
        source: Literal["ews_inbox", "ews_calendar"],
    ) -> str:
        for notification in folder.get_events(subscription_id, watermark):
            watermark = self._extract_watermark(notification, watermark)
            self._dispatch_notification(token_hash, notification.events, source=source)
        return watermark

    def _extract_watermark(self, notification: Any, fallback: str) -> str:
        if notification.events:
            last_event = notification.events[-1]
            event_watermark = getattr(last_event, "watermark", None)
            if event_watermark:
                return event_watermark
        return fallback

    def _dispatch_notification(
        self,
        token_hash: str,
        events: list[Any],
        *,
        source: Literal["ews_inbox", "ews_calendar"] = "ews_inbox",
    ) -> None:
        for event in events:
            payload = self._serialize_event(event, source=source)
            if payload is None:
                continue
            notification_hub.broadcast_json_threadsafe(
                token_hash,
                {"event": "notification", "data": payload},
            )

    def _serialize_event(
        self,
        event: Any,
        *,
        source: Literal["ews_inbox", "ews_calendar"],
    ) -> dict[str, Any] | None:
        event_name = type(event).__name__

        if isinstance(event, StatusEvent):
            return None

        category, title, body = self._event_copy(event_name, source)
        if category is None:
            return None

        timestamp = getattr(event, "timestamp", None)
        if timestamp is not None:
            ts = timestamp
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
        else:
            ts = datetime.now(timezone.utc)

        item_id = None
        raw_item_id = getattr(event, "item_id", None)
        if raw_item_id is not None:
            item_id = getattr(raw_item_id, "id", None) or str(raw_item_id)

        return {
            "id": str(uuid.uuid4()),
            "category": category,
            "title": title,
            "body": body,
            "timestamp": ts.isoformat(),
            "item_id": item_id,
            "source": source,
        }

    def _event_copy(
        self,
        event_name: str,
        source: Literal["ews_inbox", "ews_calendar"],
    ) -> tuple[str | None, str, str]:
        if event_name == "NewMailEvent":
            return (
                "new_mail",
                "Новое письмо",
                "Поступило новое сообщение во входящие",
            )

        if event_name == "CreatedEvent" and source == "ews_calendar":
            return (
                "calendar_updated",
                "Календарь",
                "Добавлено или изменено событие в календаре",
            )

        if event_name == "ModifiedEvent" and source == "ews_calendar":
            return (
                "calendar_updated",
                "Календарь",
                "Обновлено событие в календаре",
            )

        if event_name in {
            "CreatedEvent",
            "ModifiedEvent",
            "MovedEvent",
            "CopiedEvent",
            "DeletedEvent",
        }:
            return None

        logger.debug("Ignoring unsupported EWS event: %s (%s)", event_name, source)
        return None


ews_notification_service = EwsNotificationService()
