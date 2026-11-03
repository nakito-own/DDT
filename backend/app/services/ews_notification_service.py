import logging
import threading
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Literal
from zoneinfo import ZoneInfo

from exchangelib import Account
from exchangelib.errors import ErrorSubscriptionNotFound
from exchangelib.properties import StatusEvent

from app.config import settings
from app.services.ews_service import ews_service
from app.services.notification_hub import notification_hub
from app.services.notification_text import (
    describe_calendar_change,
    describe_new_mail,
    plain_text,
)
from app.services.session_service import SessionContext, session_service

logger = logging.getLogger(__name__)

INBOX_EVENT_TYPES = [
    "NewMailEvent",
    "CreatedEvent",
    "ModifiedEvent",
    "MovedEvent",
    "CopiedEvent",
    "DeletedEvent",
]
CALENDAR_EVENT_TYPES = ["CreatedEvent", "ModifiedEvent", "DeletedEvent"]


@dataclass
class _WorkerState:
    thread: threading.Thread
    stop_event: threading.Event
    clients: int = 0


class EwsNotificationService:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._workers: dict[str, _WorkerState] = {}
        self._calendar_snapshots: dict[str, dict[str, dict]] = {}
        self._recent_mail: dict[str, dict[str, float]] = {}

    def ensure_worker(self, context: SessionContext) -> None:
        token_hash = context.token_hash
        with self._lock:
            worker = self._workers.get(token_hash)
            if worker is not None and worker.thread.is_alive():
                worker.clients += 1
                worker.stop_event.clear()
                return
            if worker is not None:
                self._workers.pop(token_hash, None)

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
            logger.info(
                "Stopping EWS notification worker for token hash %s",
                token_hash[:8],
            )

    def stop_for_session(self, token_hash: str) -> None:
        with self._lock:
            worker = self._workers.get(token_hash)
            if worker is None:
                return
            worker.stop_event.set()
            worker.clients = 0

    def shutdown_all(self) -> None:
        with self._lock:
            workers = list(self._workers.values())
        for worker in workers:
            worker.stop_event.set()
            worker.clients = 0
        for worker in workers:
            worker.thread.join(timeout=5)

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
        try:
            while True:
                with self._lock:
                    worker = self._workers.get(token_hash)
                    if worker is None or worker.clients == 0:
                        break

                if not notification_hub.has_connections(token_hash):
                    if stop_event.wait(1):
                        break
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
                    if stop_event.wait(min(10, failures * 2)):
                        break
                except Exception:
                    failures += 1
                    logger.warning(
                        "EWS notification worker error for %s (attempt %s)",
                        context.email,
                        failures,
                        exc_info=True,
                    )
                    if stop_event.wait(min(30, 2 ** min(failures, 4))):
                        break
        finally:
            with self._lock:
                self._workers.pop(token_hash, None)
            self._calendar_snapshots.pop(token_hash, None)
            self._recent_mail.pop(token_hash, None)
            logger.info(
                "EWS notification worker stopped for token hash %s",
                token_hash[:8],
            )

    def _streaming_loop(
        self, context: SessionContext, stop_event: threading.Event
    ) -> None:
        account = self._create_worker_account(context)
        inbox_sub_id = account.inbox.subscribe_to_streaming(
            event_types=INBOX_EVENT_TYPES
        )
        calendar_sub_id = None
        try:
            calendar_sub_id = account.calendar.subscribe_to_streaming(
                event_types=CALENDAR_EVENT_TYPES
            )
        except Exception:
            logger.info(
                "Calendar streaming subscription unavailable for %s, inbox only",
                context.email,
            )

        self._prime_calendar(context.token_hash, account)
        try:
            while not stop_event.is_set() and notification_hub.has_connections(
                context.token_hash
            ):
                for notification in self._iter_streaming_events(
                    account, inbox_sub_id, calendar_sub_id
                ):
                    if stop_event.is_set():
                        break
                    source = self._source_for_subscription(
                        notification,
                        inbox_sub_id=inbox_sub_id,
                        calendar_sub_id=calendar_sub_id,
                    )
                    self._dispatch_notification(
                        context.token_hash,
                        notification.events,
                        source=source,
                        folder=account.calendar
                        if source == "ews_calendar"
                        else account.inbox,
                    )
        finally:
            for folder, sub_id in (
                (account.inbox, inbox_sub_id),
                (account.calendar, calendar_sub_id),
            ):
                if not sub_id:
                    continue
                try:
                    folder.unsubscribe(sub_id)
                except Exception:
                    logger.debug(
                        "Failed to unsubscribe streaming subscription",
                        exc_info=True,
                    )
            ews_service.close_account(account)

    def _iter_streaming_events(
        self,
        account: Account,
        inbox_sub_id: str,
        calendar_sub_id: str | None,
    ) -> Any:
        subscription_ids = [inbox_sub_id]
        if calendar_sub_id:
            subscription_ids.append(calendar_sub_id)
        try:
            return account.inbox.get_streaming_events(
                subscription_ids,
                connection_timeout=settings.ews_notification_stream_timeout,
            )
        except TypeError:
            return account.inbox.get_streaming_events(
                inbox_sub_id,
                connection_timeout=settings.ews_notification_stream_timeout,
            )

    def _source_for_subscription(
        self,
        notification: Any,
        *,
        inbox_sub_id: str,
        calendar_sub_id: str | None,
    ) -> Literal["ews_inbox", "ews_calendar"]:
        subscription_id = getattr(notification, "subscription_id", None)
        if calendar_sub_id and subscription_id == calendar_sub_id:
            return "ews_calendar"
        if subscription_id == inbox_sub_id:
            return "ews_inbox"
        return "ews_inbox"

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

        self._prime_calendar(context.token_hash, account)
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
                if stop_event.wait(settings.ews_notification_poll_interval):
                    break
        finally:
            for folder, sub_id in (
                (account.inbox, inbox_sub_id),
                (account.calendar, calendar_sub_id),
            ):
                try:
                    folder.unsubscribe(sub_id)
                except Exception:
                    logger.debug(
                        "Failed to unsubscribe pull subscription",
                        exc_info=True,
                    )
            ews_service.close_account(account)

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
            self._dispatch_notification(
                token_hash,
                notification.events,
                source=source,
                folder=folder,
            )
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
        folder: Any = None,
    ) -> None:
        for event in events:
            payload = self._serialize_event(
                event,
                source=source,
                token_hash=token_hash,
                folder=folder,
            )
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
        token_hash: str,
        folder: Any = None,
    ) -> dict[str, Any] | None:
        event_name = type(event).__name__

        if isinstance(event, StatusEvent):
            return None

        item_id = _event_item_id(event)
        timestamp = getattr(event, "timestamp", None)
        if timestamp is not None:
            ts = timestamp
            if getattr(ts, "tzinfo", None) is None:
                ts = ts.replace(tzinfo=timezone.utc)
        else:
            ts = datetime.now(timezone.utc)

        if source == "ews_inbox":
            return self._mail_payload(
                event_name,
                item_id,
                token_hash=token_hash,
                folder=folder,
                timestamp=ts,
            )

        if source == "ews_calendar" and event_name in {
            "CreatedEvent",
            "ModifiedEvent",
            "DeletedEvent",
        }:
            return self._calendar_payload(
                event_name,
                item_id,
                token_hash=token_hash,
                folder=folder,
                timestamp=ts,
            )

        logger.debug("Ignoring unsupported EWS event: %s (%s)", event_name, source)
        return None

    def _mail_payload(
        self,
        event_name: str,
        item_id: str | None,
        *,
        token_hash: str,
        folder: Any,
        timestamp: datetime,
    ) -> dict[str, Any] | None:
        if event_name in {"NewMailEvent", "CreatedEvent"}:
            if item_id and self._mail_already_sent(token_hash, item_id):
                return None
            subject, sender = self._load_mail_summary(folder, item_id)
            title, body = describe_new_mail(subject, sender)
            if item_id:
                self._mark_mail_sent(token_hash, item_id)
            return _payload(
                category="new_mail",
                title=title,
                body=body,
                timestamp=timestamp,
                item_id=item_id,
                source="ews_inbox",
                target_kind="mail",
                match_subject=subject,
            )

        if event_name in {
            "ModifiedEvent",
            "MovedEvent",
            "CopiedEvent",
            "DeletedEvent",
        }:
            return _payload(
                category="mail_updated",
                title="Почта",
                body="Почтовый ящик обновлён",
                timestamp=timestamp,
                item_id=item_id,
                source="ews_inbox",
                silent=True,
            )
        return None

    def _calendar_payload(
        self,
        event_name: str,
        item_id: str | None,
        *,
        token_hash: str,
        folder: Any,
        timestamp: datetime,
    ) -> dict[str, Any] | None:
        previous = None
        if item_id:
            previous = self._calendar_snapshots.get(token_hash, {}).get(item_id)
        current = None
        if event_name != "DeletedEvent" and folder is not None and item_id:
            current = self._load_calendar_snapshot(folder, item_id)
        if current is not None and item_id:
            self._calendar_snapshots.setdefault(token_hash, {})[item_id] = current
        elif event_name == "DeletedEvent" and item_id:
            self._calendar_snapshots.get(token_hash, {}).pop(item_id, None)

        described = describe_calendar_change(
            event_name,
            current,
            previous,
            zone=ZoneInfo(settings.ews_timezone),
        )
        if described is None:
            return None
        focus = described.get("focus_at")
        open_item = event_name != "DeletedEvent"
        return _payload(
            category="calendar_updated",
            title=described["title"],
            body=described["body"],
            timestamp=timestamp,
            item_id=item_id if open_item else None,
            source="ews_calendar",
            target_kind="calendar",
            focus_at=focus.isoformat() if isinstance(focus, datetime) else None,
            match_subject=described.get("subject") if open_item else None,
            silent=bool(described.get("silent")),
        )

    def _prime_calendar(self, token_hash: str, account: Account) -> None:
        zone = ZoneInfo(settings.ews_timezone)
        now = datetime.now(zone)
        start = now - timedelta(days=14)
        end = now + timedelta(days=120)
        snapshots: dict[str, dict] = {}
        try:
            for index, item in enumerate(account.calendar.view(start=start, end=end)):
                if index >= 400:
                    break
                snapshot = _snapshot_from_item(item, include_body=False)
                item_id = snapshot.get("id")
                if item_id:
                    snapshots[str(item_id)] = snapshot
        except Exception:
            logger.info(
                "Calendar snapshot for notifications is unavailable",
                exc_info=True,
            )
            return
        self._calendar_snapshots[token_hash] = snapshots

    def _load_calendar_snapshot(self, folder: Any, item_id: str) -> dict | None:
        try:
            item = folder.get(id=item_id)
        except Exception:
            logger.debug("Calendar item %s is unavailable", item_id, exc_info=True)
            return None
        snapshot = _snapshot_from_item(item, include_body=True)
        snapshot["id"] = item_id
        return snapshot

    def _load_mail_summary(
        self, folder: Any, item_id: str | None
    ) -> tuple[str | None, str | None]:
        if folder is None or not item_id:
            return None, None
        try:
            item = folder.get(id=item_id)
        except Exception:
            logger.debug("Mail item %s is unavailable", item_id, exc_info=True)
            return None, None
        subject = getattr(item, "subject", None)
        sender = getattr(item, "sender", None) or getattr(item, "author", None)
        sender_name = None
        if sender is not None:
            sender_name = getattr(sender, "name", None) or getattr(
                sender, "email_address", None
            )
        return (str(subject) if subject else None, sender_name)

    def _mail_already_sent(self, token_hash: str, item_id: str) -> bool:
        sent_at = self._recent_mail.get(token_hash, {}).get(item_id)
        return sent_at is not None and time.monotonic() - sent_at < 60

    def _mark_mail_sent(self, token_hash: str, item_id: str) -> None:
        bucket = self._recent_mail.setdefault(token_hash, {})
        now = time.monotonic()
        stale = [key for key, stamp in bucket.items() if now - stamp > 60]
        for key in stale:
            bucket.pop(key, None)
        bucket[item_id] = now


def _event_item_id(event: Any) -> str | None:
    raw_item_id = getattr(event, "item_id", None)
    if raw_item_id is None:
        return None
    item_id = getattr(raw_item_id, "id", None) or str(raw_item_id)
    return str(item_id) if item_id else None


def _read_item_body(item: Any, *, allow_fetch: bool) -> tuple[str, bool]:
    if not allow_fetch and (
        not hasattr(item, "__dict__") or "body" not in item.__dict__
    ):
        return "", False
    body = ""
    try:
        text_body = getattr(item, "text_body", None)
        body = plain_text(str(text_body) if text_body else "")
    except Exception:
        body = ""
    if not body:
        try:
            raw_body = getattr(item, "body", None)
            body = plain_text(str(raw_body) if raw_body else "")
        except Exception:
            return "", False
    return body[:4000], True


def _snapshot_from_item(item: Any, *, include_body: bool) -> dict:
    attendees: list[str] = []
    for attr in ("required_attendees", "optional_attendees"):
        for mailbox in getattr(item, attr, None) or []:
            email = getattr(mailbox, "email_address", None) or ""
            name = getattr(mailbox, "name", None) or ""
            key = str(email or name).strip().lower()
            if key:
                attendees.append(key)
    body = ""
    body_known = False
    if include_body:
        body, body_known = _read_item_body(item, allow_fetch=True)
    else:
        cached = item.__dict__.get("body") if hasattr(item, "__dict__") else None
        if cached is not None:
            body, body_known = plain_text(str(cached))[:4000], True
    return {
        "id": str(getattr(item, "id", "") or ""),
        "subject": str(getattr(item, "subject", "") or ""),
        "body": body[:4000],
        "body_known": body_known,
        "start": getattr(item, "start", None),
        "end": getattr(item, "end", None),
        "location": str(getattr(item, "location", "") or ""),
        "attendees": tuple(sorted(set(attendees))),
    }


def _payload(
    *,
    category: str,
    title: str,
    body: str,
    timestamp: datetime,
    item_id: str | None,
    source: str,
    target_kind: str | None = None,
    focus_at: str | None = None,
    match_subject: str | None = None,
    silent: bool = False,
) -> dict[str, Any]:
    return {
        "id": str(uuid.uuid4()),
        "category": category,
        "title": title,
        "body": body,
        "timestamp": timestamp.isoformat(),
        "item_id": item_id,
        "source": source,
        "target_kind": target_kind,
        "focus_at": focus_at,
        "match_subject": match_subject,
        "silent": silent,
    }


ews_notification_service = EwsNotificationService()
