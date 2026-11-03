"""Уведомления об изменениях задач для подключённых сессий."""

import logging
import uuid
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from app.config import settings
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

        old_executor = _user_id(before.get("executor_id"))
        new_executor = _user_id(after.get("executor_id"))
        if new_executor is not None and new_executor != actor_id and new_executor != old_executor:
            self._send(
                new_executor,
                category="task_assigned",
                title=task_assigned_text(title),
                body="",
                task=task,
            )
            notified.add(new_executor)
        if old_executor is not None and old_executor != actor_id and old_executor != new_executor:
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
            new_responsible is not None
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
            old_responsible is not None
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
        if not heading:
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
