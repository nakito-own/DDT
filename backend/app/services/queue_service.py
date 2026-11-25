"""Правила очереди личных задач и пространства."""

import json
import re
from datetime import datetime, timedelta

from pymysql.err import IntegrityError

from app.db import get_db
from app.schemas.queue import QueueSettingsWrite

_SYSTEM_STATUSES = (
    ("todo", "Запланировано", "open", 0),
    ("in_progress", "В работе", "active", 1),
    ("done", "Готово", "closed", 2),
)
_DEFAULT_TYPES = ("Задача", "Баг", "Улучшение")
_KEY_CLEAN = re.compile(r"[^\w]+", re.UNICODE)
_CATEGORIES = {"open", "active", "closed"}
_FIELD_TYPES = {"text", "number", "date", "list", "user", "checkbox"}


class QueueSettingsError(Exception):
    pass


def _load_json(value):
    if value is None or isinstance(value, (dict, list, int, float, bool)):
        return value
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return value
    return value


def _dump_json(value) -> str | None:
    if value is None:
        return None
    return json.dumps(value, ensure_ascii=False)


def _status_key(name: str, taken: set[str], preferred: str = "") -> str:
    raw = preferred.strip().lower() or _KEY_CLEAN.sub("_", name.strip().lower()).strip("_")
    base = (raw or "status")[:40]
    key = base
    number = 2
    while key in taken or not key:
        key = f"{base[:36]}_{number}"
        number += 1
    return key


class QueueService:
    def get_personal(self, owner_id: int) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                queue_id = self.ensure(cursor, owner_id=owner_id)
                return self._load(cursor, queue_id)

    def get_space(self, space_id: int) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                queue_id = self.ensure(cursor, space_id=space_id)
                return self._load(cursor, queue_id)

    def save_personal(self, owner_id: int, payload: QueueSettingsWrite) -> dict:
        with get_db() as conn:
            conn.autocommit(False)
            try:
                with conn.cursor() as cursor:
                    queue_id = self.ensure(cursor, owner_id=owner_id)
                    self._save(cursor, queue_id, payload)
                    saved = self._load(cursor, queue_id)
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            finally:
                conn.autocommit(True)
        return saved

    def save_space(self, space_id: int, payload: QueueSettingsWrite) -> dict:
        with get_db() as conn:
            conn.autocommit(False)
            try:
                with conn.cursor() as cursor:
                    queue_id = self.ensure(cursor, space_id=space_id)
                    self._save(cursor, queue_id, payload)
                    saved = self._load(cursor, queue_id)
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            finally:
                conn.autocommit(True)
        return saved

    def ensure(
        self,
        cursor,
        *,
        owner_id: int | None = None,
        space_id: int | None = None,
    ) -> int:
        if space_id is not None:
            cursor.execute(
                "SELECT id FROM queue_settings WHERE space_id = %s",
                (space_id,),
            )
        elif owner_id is not None:
            cursor.execute(
                "SELECT id FROM queue_settings WHERE owner_id = %s",
                (owner_id,),
            )
        else:
            raise QueueSettingsError("Очередь не задана")
        row = cursor.fetchone()
        if row:
            queue_id = row["id"]
        else:
            try:
                cursor.execute(
                    """
                    INSERT INTO queue_settings (space_id, owner_id)
                    VALUES (%s, %s)
                    """,
                    (space_id, None if space_id is not None else owner_id),
                )
            except IntegrityError:
                if space_id is not None:
                    cursor.execute(
                        "SELECT id FROM queue_settings WHERE space_id = %s",
                        (space_id,),
                    )
                else:
                    cursor.execute(
                        "SELECT id FROM queue_settings WHERE owner_id = %s",
                        (owner_id,),
                    )
                existing = cursor.fetchone()
                if not existing:
                    raise
                queue_id = existing["id"]
            else:
                queue_id = cursor.lastrowid
        self._seed_missing(cursor, queue_id)
        return queue_id

    def ensure_for_task(self, cursor, *, owner_id: int, space_id: int | None) -> int:
        if space_id is not None:
            return self.ensure(cursor, space_id=space_id)
        return self.ensure(cursor, owner_id=owner_id)

    def resolve_create(self, cursor, *, owner_id: int, space_id: int | None, payload) -> dict:
        queue_id = self.ensure_for_task(cursor, owner_id=owner_id, space_id=space_id)
        queue = self._load(cursor, queue_id)
        status_keys = {item["key"]: item for item in queue["statuses"]}
        specified = payload.model_fields_set
        status = payload.status if "status" in specified and payload.status else queue["default_status_key"]
        if status not in status_keys:
            raise QueueSettingsError("Статус не входит в очередь")
        if "type_id" in specified:
            type_id = payload.type_id
        else:
            type_id = queue["default_type_id"]
        self._require_type(queue, type_id)
        deadline = payload.deadline
        if "deadline" not in specified and queue["default_deadline_days"] is not None:
            deadline = datetime.utcnow() + timedelta(days=queue["default_deadline_days"])
        priority = payload.priority
        if "priority" not in specified and queue.get("default_priority"):
            from app.models.task import TaskPriority

            priority = TaskPriority(queue["default_priority"])
        if "field_values" in specified and payload.field_values is not None:
            values = [
                {"field_id": item.field_id, "value": item.value}
                for item in payload.field_values
            ]
        else:
            values = [
                {"field_id": field["id"], "value": field["default_value"]}
                for field in queue["fields"]
                if field["default_value"] is not None
            ]
        self._require_fields(queue, values)
        if "component_ids" in specified and payload.component_ids is not None:
            component_ids = list(payload.component_ids)
        else:
            component_ids = list(queue["default_component_ids"])
        self._require_components(queue, component_ids)
        if "notifications" in specified and payload.notifications is not None:
            notes = payload.notifications
            notifications = {
                "notify_assigned": notes.notify_assigned,
                "notify_updated": notes.notify_updated,
                "notify_comment": notes.notify_comment,
                "notify_deleted": notes.notify_deleted,
                "deadline_reminder_hours": notes.deadline_reminder_hours,
            }
        else:
            notifications = {
                "notify_assigned": queue["notify_assigned"],
                "notify_updated": queue["notify_updated"],
                "notify_comment": queue["notify_comment"],
                "notify_deleted": queue["notify_deleted"],
                "deadline_reminder_hours": queue["deadline_reminder_hours"],
            }
        return {
            "queue": queue,
            "status": status,
            "category": status_keys[status]["category"],
            "type_id": type_id,
            "deadline": deadline,
            "priority": priority,
            "field_values": values,
            "component_ids": component_ids,
            "notifications": notifications,
        }

    def validate_status(self, cursor, *, owner_id: int, space_id: int | None, status: str) -> dict:
        queue_id = self.ensure_for_task(cursor, owner_id=owner_id, space_id=space_id)
        cursor.execute(
            """
            SELECT status_key, name, category
            FROM queue_statuses
            WHERE queue_id = %s AND status_key = %s
            """,
            (queue_id, status),
        )
        row = cursor.fetchone()
        if not row:
            raise QueueSettingsError("Статус не входит в очередь")
        return {
            "key": row["status_key"],
            "name": row["name"],
            "category": row["category"],
        }

    def validate_type(self, cursor, *, owner_id: int, space_id: int | None, type_id: int | None) -> None:
        if type_id is None:
            return
        queue_id = self.ensure_for_task(cursor, owner_id=owner_id, space_id=space_id)
        cursor.execute(
            "SELECT id FROM queue_task_types WHERE id = %s AND queue_id = %s",
            (type_id, queue_id),
        )
        if not cursor.fetchone():
            raise QueueSettingsError("Тип задачи не входит в очередь")

    def replace_task_fields(self, cursor, task_id: int, queue: dict, values: list[dict]) -> None:
        self._require_fields(queue, values)
        cursor.execute("DELETE FROM task_field_values WHERE task_id = %s", (task_id,))
        for item in values:
            if item.get("value") is None:
                continue
            cursor.execute(
                """
                INSERT INTO task_field_values (task_id, field_id, value_json)
                VALUES (%s, %s, %s)
                """,
                (task_id, item["field_id"], _dump_json(item["value"])),
            )

    def replace_task_components(self, cursor, task_id: int, queue: dict, component_ids: list[int]) -> None:
        self._require_components(queue, component_ids)
        cursor.execute("DELETE FROM task_components WHERE task_id = %s", (task_id,))
        for component_id in component_ids:
            cursor.execute(
                """
                INSERT INTO task_components (task_id, component_id)
                VALUES (%s, %s)
                """,
                (task_id, component_id),
            )

    def replace_task_notifications(self, cursor, task_id: int, notifications: dict) -> None:
        hours = notifications.get("deadline_reminder_hours")
        if hours is not None and int(hours) < 1:
            raise QueueSettingsError("Напоминание о дедлайне задаётся в часах")
        cursor.execute(
            """
            INSERT INTO task_notification_settings (
              task_id, notify_assigned, notify_updated, notify_comment,
              notify_deleted, deadline_reminder_hours
            ) VALUES (%s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
              notify_assigned = VALUES(notify_assigned),
              notify_updated = VALUES(notify_updated),
              notify_comment = VALUES(notify_comment),
              notify_deleted = VALUES(notify_deleted),
              deadline_reminder_hours = VALUES(deadline_reminder_hours)
            """,
            (
                task_id,
                int(bool(notifications.get("notify_assigned", True))),
                int(bool(notifications.get("notify_updated", True))),
                int(bool(notifications.get("notify_comment", True))),
                int(bool(notifications.get("notify_deleted", True))),
                hours,
            ),
        )

    def queue_for_task_row(self, cursor, row) -> dict:
        queue_id = self.ensure_for_task(
            cursor,
            owner_id=row["owner_id"],
            space_id=row.get("space_id"),
        )
        return self._load(cursor, queue_id)

    def _seed_missing(self, cursor, queue_id: int) -> None:
        cursor.execute(
            "SELECT status_key FROM queue_statuses WHERE queue_id = %s",
            (queue_id,),
        )
        present = {row["status_key"] for row in cursor.fetchall()}
        for key, name, category, order in _SYSTEM_STATUSES:
            if key in present:
                continue
            cursor.execute(
                """
                INSERT INTO queue_statuses (
                  queue_id, status_key, name, category, sort_order, is_system
                ) VALUES (%s, %s, %s, %s, %s, TRUE)
                """,
                (queue_id, key, name, category, order),
            )
        cursor.execute(
            "SELECT name FROM queue_task_types WHERE queue_id = %s",
            (queue_id,),
        )
        type_names = {row["name"] for row in cursor.fetchall()}
        if not type_names:
            for index, name in enumerate(_DEFAULT_TYPES):
                cursor.execute(
                    """
                    INSERT INTO queue_task_types (queue_id, name, sort_order)
                    VALUES (%s, %s, %s)
                    """,
                    (queue_id, name, index),
                )
        cursor.execute(
            """
            SELECT default_status_id, default_type_id
            FROM queue_settings
            WHERE id = %s
            """,
            (queue_id,),
        )
        current = cursor.fetchone()
        if current["default_status_id"] is None:
            cursor.execute(
                """
                UPDATE queue_settings q
                JOIN queue_statuses s ON s.queue_id = q.id AND s.status_key = 'todo'
                SET q.default_status_id = s.id
                WHERE q.id = %s
                """,
                (queue_id,),
            )
        if current["default_type_id"] is None:
            cursor.execute(
                """
                UPDATE queue_settings q
                JOIN queue_task_types t ON t.queue_id = q.id AND t.name = 'Задача'
                SET q.default_type_id = t.id
                WHERE q.id = %s
                """,
                (queue_id,),
            )
            cursor.execute(
                "SELECT default_type_id FROM queue_settings WHERE id = %s",
                (queue_id,),
            )
            if cursor.fetchone()["default_type_id"] is None:
                cursor.execute(
                    """
                    UPDATE queue_settings
                    SET default_type_id = (
                      SELECT id FROM queue_task_types
                      WHERE queue_id = %s
                      ORDER BY sort_order, id
                      LIMIT 1
                    )
                    WHERE id = %s
                    """,
                    (queue_id, queue_id),
                )

    def _save(self, cursor, queue_id: int, payload: QueueSettingsWrite) -> None:
        self._save_statuses(cursor, queue_id, payload)
        self._save_types(cursor, queue_id, payload)
        self._save_fields(cursor, queue_id, payload)
        self._save_components(cursor, queue_id, payload)
        cursor.execute(
            """
            UPDATE queue_settings
            SET default_deadline_days = %s,
                default_priority = %s,
                notify_assigned = %s,
                notify_updated = %s,
                notify_comment = %s,
                notify_deleted = %s,
                deadline_reminder_hours = %s
            WHERE id = %s
            """,
            (
                payload.default_deadline_days,
                payload.default_priority.value if payload.default_priority else None,
                int(payload.notify_assigned),
                int(payload.notify_updated),
                int(payload.notify_comment),
                int(payload.notify_deleted),
                payload.deadline_reminder_hours,
                queue_id,
            ),
        )

    def _save_statuses(self, cursor, queue_id: int, payload: QueueSettingsWrite) -> None:
        cursor.execute(
            """
            SELECT id, status_key, is_system
            FROM queue_statuses
            WHERE queue_id = %s
            """,
            (queue_id,),
        )
        existing = {row["id"]: row for row in cursor.fetchall()}
        by_key = {row["status_key"]: row for row in existing.values()}
        seen_ids: set[int] = set()
        taken = set(by_key)
        incoming_keys: list[str] = []
        for index, item in enumerate(payload.statuses):
            if item.category not in _CATEGORIES:
                raise QueueSettingsError("Неизвестная категория статуса")
            row = existing.get(item.id) if item.id else None
            if row is None and item.key:
                row = by_key.get(item.key.strip())
            if row and row["is_system"]:
                key = row["status_key"]
                if item.key and item.key != key:
                    raise QueueSettingsError("Ключ системного статуса менять нельзя")
            elif row:
                key = item.key.strip() or row["status_key"]
            else:
                key = _status_key(item.name, taken, item.key)
            if key in incoming_keys:
                raise QueueSettingsError("Статусы очереди должны отличаться")
            incoming_keys.append(key)
            taken.add(key)
            if row:
                cursor.execute(
                    """
                    UPDATE queue_statuses
                    SET status_key = %s, name = %s, category = %s, sort_order = %s
                    WHERE id = %s AND queue_id = %s
                    """,
                    (key, item.name.strip(), item.category, index, row["id"], queue_id),
                )
                seen_ids.add(row["id"])
            else:
                cursor.execute(
                    """
                    INSERT INTO queue_statuses (
                      queue_id, status_key, name, category, sort_order, is_system
                    ) VALUES (%s, %s, %s, %s, %s, FALSE)
                    """,
                    (queue_id, key, item.name.strip(), item.category, index),
                )
                seen_ids.add(cursor.lastrowid)
        removed = [row for row_id, row in existing.items() if row_id not in seen_ids]
        for row in removed:
            if row["is_system"]:
                raise QueueSettingsError("Системный статус нельзя удалить")
            if self._status_in_use(cursor, queue_id, row["status_key"]):
                raise QueueSettingsError(
                    f"Статус «{row['status_key']}» используется в задачах"
                )
            cursor.execute(
                "DELETE FROM queue_statuses WHERE id = %s AND queue_id = %s",
                (row["id"], queue_id),
            )
        system_keys = {key for key, *_rest in _SYSTEM_STATUSES}
        if not system_keys.issubset(set(incoming_keys)):
            raise QueueSettingsError("В очереди должны остаться системные статусы")
        if payload.default_status_key not in incoming_keys:
            raise QueueSettingsError("Статус по умолчанию должен быть в списке")
        cursor.execute(
            """
            UPDATE queue_settings q
            JOIN queue_statuses s ON s.queue_id = q.id AND s.status_key = %s
            SET q.default_status_id = s.id
            WHERE q.id = %s
            """,
            (payload.default_status_key, queue_id),
        )

    def _save_types(self, cursor, queue_id: int, payload: QueueSettingsWrite) -> None:
        cursor.execute(
            "SELECT id, name FROM queue_task_types WHERE queue_id = %s",
            (queue_id,),
        )
        existing = {row["id"]: row for row in cursor.fetchall()}
        seen: set[int] = set()
        names: list[str] = []
        for index, item in enumerate(payload.types):
            name = item.name.strip()
            if name in names:
                raise QueueSettingsError("Типы задач должны отличаться")
            names.append(name)
            row = existing.get(item.id) if item.id else None
            if row:
                cursor.execute(
                    """
                    UPDATE queue_task_types
                    SET name = %s, sort_order = %s
                    WHERE id = %s AND queue_id = %s
                    """,
                    (name, index, row["id"], queue_id),
                )
                seen.add(row["id"])
            else:
                cursor.execute(
                    """
                    INSERT INTO queue_task_types (queue_id, name, sort_order)
                    VALUES (%s, %s, %s)
                    """,
                    (queue_id, name, index),
                )
                seen.add(cursor.lastrowid)
        for row_id, row in existing.items():
            if row_id in seen:
                continue
            if self._type_in_use(cursor, row_id):
                raise QueueSettingsError(f"Тип «{row['name']}» используется в задачах")
            cursor.execute(
                "DELETE FROM queue_task_types WHERE id = %s AND queue_id = %s",
                (row_id, queue_id),
            )
        if payload.default_type_name.strip() not in names:
            raise QueueSettingsError("Тип по умолчанию должен быть в списке")
        cursor.execute(
            """
            UPDATE queue_settings q
            JOIN queue_task_types t ON t.queue_id = q.id AND t.name = %s
            SET q.default_type_id = t.id
            WHERE q.id = %s
            """,
            (payload.default_type_name.strip(), queue_id),
        )

    def _save_fields(self, cursor, queue_id: int, payload: QueueSettingsWrite) -> None:
        cursor.execute(
            "SELECT id FROM queue_fields WHERE queue_id = %s",
            (queue_id,),
        )
        existing = {row["id"] for row in cursor.fetchall()}
        seen: set[int] = set()
        for index, item in enumerate(payload.fields):
            if item.field_type not in _FIELD_TYPES:
                raise QueueSettingsError("Неизвестный тип поля")
            if item.field_type == "list" and not item.options:
                raise QueueSettingsError(f"У поля «{item.name}» нет вариантов списка")
            options = item.options if item.field_type == "list" else []
            default_value = item.default_value
            if item.field_type != "list":
                list_multiple = False
            else:
                list_multiple = item.list_multiple
            if item.id and item.id in existing:
                cursor.execute(
                    """
                    UPDATE queue_fields
                    SET name = %s, field_type = %s, list_multiple = %s,
                        options_json = %s, default_value_json = %s, sort_order = %s
                    WHERE id = %s AND queue_id = %s
                    """,
                    (
                        item.name.strip(),
                        item.field_type,
                        int(list_multiple),
                        _dump_json(options),
                        _dump_json(default_value),
                        index,
                        item.id,
                        queue_id,
                    ),
                )
                seen.add(item.id)
            else:
                cursor.execute(
                    """
                    INSERT INTO queue_fields (
                      queue_id, name, field_type, list_multiple,
                      options_json, default_value_json, sort_order
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        queue_id,
                        item.name.strip(),
                        item.field_type,
                        int(list_multiple),
                        _dump_json(options),
                        _dump_json(default_value),
                        index,
                    ),
                )
                seen.add(cursor.lastrowid)
        for field_id in existing - seen:
            cursor.execute(
                "DELETE FROM queue_fields WHERE id = %s AND queue_id = %s",
                (field_id, queue_id),
            )

    def _save_components(self, cursor, queue_id: int, payload: QueueSettingsWrite) -> None:
        cursor.execute(
            "SELECT id, name FROM queue_components WHERE queue_id = %s",
            (queue_id,),
        )
        existing = {row["id"]: row for row in cursor.fetchall()}
        seen: set[int] = set()
        names: list[str] = []
        default_ids: list[int] = []
        for index, item in enumerate(payload.components):
            name = item.name.strip()
            if name in names:
                raise QueueSettingsError("Компоненты должны отличаться")
            names.append(name)
            row = existing.get(item.id) if item.id else None
            if row:
                cursor.execute(
                    """
                    UPDATE queue_components
                    SET name = %s, sort_order = %s
                    WHERE id = %s AND queue_id = %s
                    """,
                    (name, index, row["id"], queue_id),
                )
                component_id = row["id"]
            else:
                cursor.execute(
                    """
                    INSERT INTO queue_components (queue_id, name, sort_order)
                    VALUES (%s, %s, %s)
                    """,
                    (queue_id, name, index),
                )
                component_id = cursor.lastrowid
            seen.add(component_id)
            if item.is_default:
                default_ids.append(component_id)
        for component_id in list(existing):
            if component_id in seen:
                continue
            cursor.execute(
                "DELETE FROM queue_components WHERE id = %s AND queue_id = %s",
                (component_id, queue_id),
            )
        cursor.execute(
            "DELETE FROM queue_default_components WHERE queue_id = %s",
            (queue_id,),
        )
        for component_id in default_ids:
            cursor.execute(
                """
                INSERT INTO queue_default_components (queue_id, component_id)
                VALUES (%s, %s)
                """,
                (queue_id, component_id),
            )

    def _status_in_use(self, cursor, queue_id: int, status_key: str) -> bool:
        cursor.execute(
            """
            SELECT 1
            FROM tasks t
            JOIN queue_settings q ON q.id = %s
            WHERE t.status = %s
              AND (
                (q.space_id IS NOT NULL AND t.space_id = q.space_id)
                OR (
                  q.space_id IS NULL
                  AND t.space_id IS NULL
                  AND t.owner_id = q.owner_id
                )
              )
            LIMIT 1
            """,
            (queue_id, status_key),
        )
        return cursor.fetchone() is not None

    def _type_in_use(self, cursor, type_id: int) -> bool:
        cursor.execute(
            "SELECT 1 FROM tasks WHERE type_id = %s LIMIT 1",
            (type_id,),
        )
        return cursor.fetchone() is not None

    def _require_type(self, queue: dict, type_id: int | None) -> None:
        if type_id is None:
            return
        if not any(item["id"] == type_id for item in queue["types"]):
            raise QueueSettingsError("Тип задачи не входит в очередь")

    def _require_fields(self, queue: dict, values: list[dict]) -> None:
        known = {item["id"] for item in queue["fields"]}
        for item in values:
            if item["field_id"] not in known:
                raise QueueSettingsError("Поле не входит в очередь")

    def _require_components(self, queue: dict, component_ids: list[int]) -> None:
        known = {item["id"] for item in queue["components"]}
        for component_id in component_ids:
            if component_id not in known:
                raise QueueSettingsError("Компонент не входит в очередь")

    def _load(self, cursor, queue_id: int) -> dict:
        cursor.execute("SELECT * FROM queue_settings WHERE id = %s", (queue_id,))
        queue = cursor.fetchone()
        cursor.execute(
            """
            SELECT id, status_key, name, category, sort_order, is_system
            FROM queue_statuses
            WHERE queue_id = %s
            ORDER BY sort_order, id
            """,
            (queue_id,),
        )
        statuses = [
            {
                "id": row["id"],
                "key": row["status_key"],
                "name": row["name"],
                "category": row["category"],
                "sort_order": row["sort_order"],
                "is_system": bool(row["is_system"]),
            }
            for row in cursor.fetchall()
        ]
        cursor.execute(
            """
            SELECT id, name, sort_order
            FROM queue_task_types
            WHERE queue_id = %s
            ORDER BY sort_order, id
            """,
            (queue_id,),
        )
        types = list(cursor.fetchall())
        cursor.execute(
            """
            SELECT id, name, field_type, list_multiple, options_json,
                   default_value_json, sort_order
            FROM queue_fields
            WHERE queue_id = %s
            ORDER BY sort_order, id
            """,
            (queue_id,),
        )
        fields = [
            {
                "id": row["id"],
                "name": row["name"],
                "field_type": row["field_type"],
                "list_multiple": bool(row["list_multiple"]),
                "options": _load_json(row["options_json"]) or [],
                "default_value": _load_json(row["default_value_json"]),
                "sort_order": row["sort_order"],
            }
            for row in cursor.fetchall()
        ]
        cursor.execute(
            """
            SELECT id, name, sort_order
            FROM queue_components
            WHERE queue_id = %s
            ORDER BY sort_order, id
            """,
            (queue_id,),
        )
        components = list(cursor.fetchall())
        cursor.execute(
            """
            SELECT component_id
            FROM queue_default_components
            WHERE queue_id = %s
            """,
            (queue_id,),
        )
        default_component_ids = [row["component_id"] for row in cursor.fetchall()]
        default_ids = set(default_component_ids)
        status_by_id = {item["id"]: item for item in statuses}
        type_by_id = {item["id"]: item for item in types}
        default_status = status_by_id.get(queue["default_status_id"]) or statuses[0]
        default_type = type_by_id.get(queue["default_type_id"])
        return {
            "id": queue["id"],
            "space_id": queue["space_id"],
            "owner_id": queue["owner_id"],
            "default_status_key": default_status["key"],
            "default_type_id": default_type["id"] if default_type else None,
            "default_type_name": default_type["name"] if default_type else None,
            "default_deadline_days": queue["default_deadline_days"],
            "default_priority": queue.get("default_priority"),
            "notify_assigned": bool(queue["notify_assigned"]),
            "notify_updated": bool(queue["notify_updated"]),
            "notify_comment": bool(queue["notify_comment"]),
            "notify_deleted": bool(queue["notify_deleted"]),
            "deadline_reminder_hours": queue["deadline_reminder_hours"],
            "statuses": statuses,
            "types": types,
            "fields": fields,
            "components": [
                {
                    "id": row["id"],
                    "name": row["name"],
                    "sort_order": row["sort_order"],
                    "is_default": row["id"] in default_ids,
                }
                for row in components
            ],
            "default_component_ids": default_component_ids,
        }


queue_service = QueueService()
