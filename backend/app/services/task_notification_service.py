"""Уведомления об изменениях задач для подключённых сессий."""

import logging
import threading
import uuid
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from app.config import settings
from app.db import get_db
from app.services.notification_hub import notification_hub
from app.services.notification_text import (
    describe_task_update,
    pack_messages,
    task_assigned_text,
    task_comment_text,
    task_deleted_text,
    task_responsible_text,
    task_unassigned_text,
    task_unresponsible_text,
)
from app.services.session_service import session_service

logger = logging.getLogger(__name__)

_PARTICIPANT_KEYS = ("author_id", "executor_id", "responsible_id", "owner_id")


class TaskNotificationService:
    def notify_created(
        self,
        *,
        actor_id: int,
        task: dict,
        comment: str | None = None,
    ) -> None:
        title = task.get("title")
        comment_preview = " ".join(str(comment or "").split())
        if not self._enabled(task, "notify_assigned"):
            return
        executor_id = _user_id(task.get("executor_id"))
        responsible_id = _user_id(task.get("responsible_id"))
        if executor_id is not None and executor_id != actor_id:
            self._send(
                executor_id,
                category="task_assigned",
                title=task_assigned_text(title),
                body=comment_preview,
                task=task,
            )
        if (
            responsible_id is not None
            and responsible_id != actor_id
            and responsible_id != executor_id
        ):
            self._send(
                responsible_id,
                category="task_assigned",
                title=task_responsible_text(title),
                body="",
                task=task,
            )

    def notify_updated(self, *, actor_id: int, before: dict, after: dict) -> None:
        task = after
        title = after.get("title") or before.get("title")
        notified: set[int] = set()

        allow_assigned = self._enabled(after, "notify_assigned")
        allow_updated = self._enabled(after, "notify_updated")
        old_executor = _user_id(before.get("executor_id"))
        new_executor = _user_id(after.get("executor_id"))
        if (
            allow_assigned
            and new_executor is not None
            and new_executor != actor_id
            and new_executor != old_executor
        ):
            self._send(
                new_executor,
                category="task_assigned",
                title=task_assigned_text(title),
                body="",
                task=task,
            )
            notified.add(new_executor)
        if (
            allow_assigned
            and old_executor is not None
            and old_executor != actor_id
            and old_executor != new_executor
        ):
            self._send(
                old_executor,
                category="task_updated",
                title=task_unassigned_text(title),
                body="",
                task=task,
            )
            notified.add(old_executor)

        old_responsible = _user_id(before.get("responsible_id"))
        new_responsible = _user_id(after.get("responsible_id"))
        if (
            allow_assigned
            and new_responsible is not None
            and new_responsible != actor_id
            and new_responsible != old_responsible
            and new_responsible not in notified
        ):
            self._send(
                new_responsible,
                category="task_assigned",
                title=task_responsible_text(title),
                body="",
                task=task,
            )
            notified.add(new_responsible)
        if (
            allow_assigned
            and old_responsible is not None
            and old_responsible != actor_id
            and old_responsible != new_responsible
            and old_responsible not in notified
        ):
            self._send(
                old_responsible,
                category="task_updated",
                title=task_unresponsible_text(title),
                body="",
                task=task,
            )
            notified.add(old_responsible)

        messages = describe_task_update(before, after, zone=_zone())
        heading, details = pack_messages(messages)
        if not heading or not allow_updated:
            return
        recipients = _participants(before) | _participants(after)
        recipients.discard(actor_id)
        recipients -= notified
        for user_id in recipients:
            self._send(
                user_id,
                category="task_updated",
                title=heading,
                body=details,
                task=task,
            )

    def notify_comment(self, *, actor_id: int, task: dict, text: str) -> None:
        if not self._enabled(task, "notify_comment"):
            return
        heading, details = task_comment_text(task.get("title"), text)
        for user_id in _participants(task):
            if user_id == actor_id:
                continue
            self._send(
                user_id,
                category="task_updated",
                title=heading,
                body=details,
                task=task,
            )

    def notify_deleted(self, *, actor_id: int, task: dict) -> None:
        if not self._enabled(task, "notify_deleted"):
            return
        heading = task_deleted_text(task.get("title"))
        for user_id in _participants(task):
            if user_id == actor_id:
                continue
            self._send(
                user_id,
                category="task_updated",
                title=heading,
                body="",
                task=task,
            )

    def _send(
        self,
        user_id: int,
        *,
        category: str,
        title: str,
        body: str,
        task: dict,
    ) -> None:
        task_key = str(task.get("key") or task.get("task_key") or "")
        space_key = task.get("space_key") or None
        payload = {
            "id": str(uuid.uuid4()),
            "category": category,
            "title": title,
            "body": body,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "item_id": task_key or None,
            "source": "tasks",
            "target_kind": "task",
            "task_key": task_key or None,
            "space_key": space_key,
            "silent": False,
        }
        delivered = False
        for token_hash in session_service.token_hashes_for_user(user_id):
            if not notification_hub.has_connections(token_hash):
                continue
            notification_hub.broadcast_json_threadsafe(
                token_hash,
                {"event": "notification", "data": payload},
            )
            delivered = True
            payload = {**payload, "id": str(uuid.uuid4())}
        if not delivered:
            logger.debug("No live notification socket for user %s", user_id)
        return delivered

    def _enabled(self, task: dict, flag: str) -> bool:
        notes = task.get("notifications")
        if isinstance(notes, dict) and flag in notes:
            return bool(notes[flag])
        task_id = _user_id(task.get("id"))
        if task_id is None:
            return True
        if flag not in {
            "notify_assigned",
            "notify_updated",
            "notify_comment",
            "notify_deleted",
        }:
            return True
        try:
            with get_db() as conn:
                with conn.cursor() as cursor:
                    cursor.execute(
                        f"SELECT {flag} AS enabled FROM task_notification_settings WHERE task_id = %s",
                        (task_id,),
                    )
                    row = cursor.fetchone()
        except Exception:
            logger.debug("Notification settings lookup failed", exc_info=True)
            return True
        if not row:
            return True
        return bool(row["enabled"])


def _zone() -> ZoneInfo:
    return ZoneInfo(settings.ews_timezone)


def _user_id(value) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _participants(task: dict) -> set[int]:
    found: set[int] = set()
    for key in _PARTICIPANT_KEYS:
        user_id = _user_id(task.get(key))
        if user_id is not None:
            found.add(user_id)
    return found


task_notification_service = TaskNotificationService()


class TaskDeadlineReminderService:
    """Один раз напоминает о дедлайне, пока срок или число часов не изменятся."""

    def __init__(self) -> None:
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._loop,
            name="task-deadline-reminders",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        thread = self._thread
        if thread is not None:
            thread.join(timeout=5)
        self._thread = None

    def _loop(self) -> None:
        while not self._stop.wait(60):
            try:
                self.scan()
            except Exception:
                logger.warning("Deadline reminder scan failed", exc_info=True)

    def scan(self) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                      t.id, t.title, t.task_key, t.deadline,
                      t.author_id, t.executor_id, t.responsible_id, t.owner_id,
                      s.space_key,
                      n.deadline_reminder_hours, n.reminder_deadline, n.reminder_hours
                    FROM tasks t
                    JOIN task_notification_settings n ON n.task_id = t.id
                    LEFT JOIN spaces s ON s.id = t.space_id
                    WHERE t.deleted = 0
                      AND t.deadline IS NOT NULL
                      AND n.deadline_reminder_hours IS NOT NULL
                      AND t.deadline > UTC_TIMESTAMP()
                      AND t.deadline <= DATE_ADD(
                        UTC_TIMESTAMP(),
                        INTERVAL n.deadline_reminder_hours HOUR
                      )
                    """
                )
                rows = list(cursor.fetchall())
        for row in rows:
            if (
                row["reminder_deadline"] == row["deadline"]
                and row["reminder_hours"] == row["deadline_reminder_hours"]
            ):
                continue
            task = {
                "id": row["id"],
                "title": row["title"],
                "key": row["task_key"],
                "task_key": row["task_key"],
                "space_key": row["space_key"],
                "author_id": row["author_id"],
                "executor_id": row["executor_id"],
                "responsible_id": row["responsible_id"],
                "owner_id": row["owner_id"],
            }
            delivered = False
            hours = row["deadline_reminder_hours"]
            for user_id in _participants(task):
                sent = task_notification_service._send(
                    user_id,
                    category="task_updated",
                    title=f"Дедлайн задачи «{row['title']}»",
                    body=f"До срока осталось не больше {hours} ч.",
                    task=task,
                )
                delivered = delivered or bool(sent)
            if not delivered:
                continue
            with get_db() as conn:
                with conn.cursor() as cursor:
                    cursor.execute(
                        """
                        UPDATE task_notification_settings
                        SET reminder_deadline = %s, reminder_hours = %s
                        WHERE task_id = %s
                        """,
                        (row["deadline"], hours, row["id"]),
                    )


task_deadline_reminder_service = TaskDeadlineReminderService()
