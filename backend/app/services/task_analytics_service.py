"""Агрегаты дашбордов аналитики по задачам (личные и пространство)."""

from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from statistics import median
from typing import Any

from fastapi import HTTPException, status

from app.db import get_db
from app.models.task import TASK_PRIORITIES, TaskPriority, TaskStatus
from app.services.analytics_queries import AnalyticsFilterSpec, TREND_GROUPINGS
from app.services.space_service import SpaceNotFoundError, space_service
from app.services.task_service import task_service

TOP_CHART_LIMIT = 10
EXECUTOR_TREND_LIMIT = 5
EMPTY_LABEL = "—"

STATUS_LABELS = {
    TaskStatus.TODO.value: "Запланировано",
    TaskStatus.IN_PROGRESS.value: "В работе",
    TaskStatus.DONE.value: "Готово",
}

PRIORITY_LABELS = {
    TaskPriority.INSIGNIFICANT.value: "Незначительный",
    TaskPriority.LOW.value: "Низкий",
    TaskPriority.MEDIUM.value: "Средний",
    TaskPriority.HIGH.value: "Высокий",
    TaskPriority.BLOCKER.value: "Блокер",
}

DATE_COLUMNS = (
    ("created_at", "Дата создания"),
    ("time_set", "Дата постановки"),
    ("time_start", "Дата начала"),
    ("time_end", "Дата завершения"),
    ("deadline", "Дедлайн"),
)


@dataclass(frozen=True)
class TaskAnalyticsScope:
    kind: str
    owner_id: int | None = None
    space_id: int | None = None
    space_name: str | None = None


def _user_label(row: dict | None) -> str:
    if not row:
        return EMPTY_LABEL
    for key in ("display_name", "name", "username", "email"):
        value = (row.get(key) or "").strip()
        if value:
            return value
    return EMPTY_LABEL


def _as_date(value: datetime | date | None) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    return value


def _hours_between(start: datetime | None, end: datetime | None) -> float | None:
    if start is None or end is None:
        return None
    delta = end - start
    return max(delta.total_seconds() / 3600.0, 0.0)


def _resolution_start(row: dict) -> datetime | None:
    return row.get("time_start") or row.get("time_set") or row.get("created_at")


def _resolution_hours(row: dict) -> float | None:
    if row.get("status") != TaskStatus.DONE.value:
        return None
    end = row.get("time_end")
    if end is None:
        return None
    return _hours_between(_resolution_start(row), end)


def _is_overdue_deadline(row: dict, now: datetime) -> bool:
    deadline = row.get("deadline")
    if deadline is None:
        return False
    if row.get("status") == TaskStatus.DONE.value:
        completed = row.get("time_end")
        return completed is not None and completed > deadline
    return deadline < now


def _bucket_key(day: date, grouping: str) -> str:
    if grouping == "day":
        return day.isoformat()
    if grouping == "week":
        monday = day - timedelta(days=day.weekday())
        return monday.isoformat()
    return f"{day.year:04d}-{day.month:02d}"


def _bucket_label(key: str, grouping: str) -> str:
    if grouping == "month":
        year, month = key.split("-", 1)
        return f"{month}.{year}"
    parsed = date.fromisoformat(key)
    if grouping == "week":
        return f"нед. {parsed.strftime('%d.%m')}"
    return parsed.strftime("%d.%m")


def _build_columns(
    rows: list[dict],
    types: dict[int, str],
    users: dict[int, str],
) -> list[dict]:
    def options_for(key: str, label_fn) -> list[dict]:
        counter: Counter[str] = Counter()
        for row in rows:
            counter[label_fn(row)] += 1
        return [
            {"key": key_value, "label": key_value, "value": count}
            for key_value, count in counter.most_common()
        ]

    status_options = [
        {
            "key": status.value,
            "label": STATUS_LABELS[status.value],
            "value": sum(1 for row in rows if row.get("status") == status.value),
        }
        for status in TaskStatus
    ]
    priority_options = [
        {
            "key": priority.value,
            "label": PRIORITY_LABELS[priority.value],
            "value": sum(1 for row in rows if row.get("priority") == priority.value),
        }
        for priority in TASK_PRIORITIES
        if any(row.get("priority") == priority.value for row in rows)
    ]
    type_options = []
    for type_id, name in sorted(types.items(), key=lambda item: item[1].lower()):
        count = sum(1 for row in rows if row.get("type_id") == type_id)
        if count > 0:
            type_options.append(
                {"key": str(type_id), "label": name, "value": count},
            )

    def user_options_by_id(field: str) -> list[dict]:
        counter: Counter[int | None] = Counter()
        for row in rows:
            counter[row.get(field)] += 1
        items = []
        for user_id, count in counter.most_common():
            label = users.get(user_id, EMPTY_LABEL) if user_id is not None else EMPTY_LABEL
            key = str(user_id) if user_id is not None else EMPTY_LABEL
            items.append({"key": key, "label": label, "value": count})
        return items

    return [
        *[
            {"key": key, "label": label, "kind": "date", "computed": False, "options": []}
            for key, label in DATE_COLUMNS
        ],
        {
            "key": "status",
            "label": "Статус",
            "kind": "text",
            "computed": False,
            "options": status_options,
        },
        {
            "key": "priority",
            "label": "Приоритет",
            "kind": "text",
            "computed": False,
            "options": priority_options,
        },
        {
            "key": "type_id",
            "label": "Тип задачи",
            "kind": "text",
            "computed": False,
            "options": type_options,
        },
        {
            "key": "executor_id",
            "label": "Исполнитель",
            "kind": "text",
            "computed": False,
            "options": user_options_by_id("executor_id"),
        },
        {
            "key": "author_id",
            "label": "Автор",
            "kind": "text",
            "computed": False,
            "options": user_options_by_id("author_id"),
        },
        {
            "key": "responsible_id",
            "label": "Ответственный",
            "kind": "text",
            "computed": False,
            "options": user_options_by_id("responsible_id"),
        },
        {
            "key": "archive",
            "label": "В архиве",
            "kind": "text",
            "computed": True,
            "options": [
                {
                    "key": "1",
                    "label": "Да",
                    "value": sum(1 for row in rows if row.get("archive")),
                },
                {
                    "key": "0",
                    "label": "Нет",
                    "value": sum(1 for row in rows if not row.get("archive")),
                },
            ],
        },
        {
            "key": "overdue_deadline",
            "label": "Просрочен дедлайн",
            "kind": "text",
            "computed": True,
            "options": [
                {
                    "key": "yes",
                    "label": "Да",
                    "value": sum(
                        1
                        for row in rows
                        if _is_overdue_deadline(row, datetime.now())
                    ),
                },
                {
                    "key": "no",
                    "label": "Нет",
                    "value": sum(
                        1
                        for row in rows
                        if not _is_overdue_deadline(row, datetime.now())
                    ),
                },
            ],
        },
    ]


def _normalize_row(
    row: dict,
    *,
    types: dict[int, str],
    users: dict[int, str],
    now: datetime,
) -> dict[str, Any]:
    type_name = types.get(row.get("type_id"), EMPTY_LABEL) if row.get("type_id") else EMPTY_LABEL
    fields = {
        "status": row.get("status") or "",
        "priority": row.get("priority") or "",
        "type_id": str(row.get("type_id") or EMPTY_LABEL),
        "executor_id": str(row.get("executor_id") or EMPTY_LABEL),
        "author_id": str(row.get("author_id") or EMPTY_LABEL),
        "responsible_id": str(row.get("responsible_id") or EMPTY_LABEL),
        "archive": "1" if row.get("archive") else "0",
        "overdue_deadline": "yes" if _is_overdue_deadline(row, now) else "no",
        "type": type_name,
        "executor": users.get(row.get("executor_id"), EMPTY_LABEL)
        if row.get("executor_id")
        else EMPTY_LABEL,
        "author": users.get(row.get("author_id"), EMPTY_LABEL)
        if row.get("author_id")
        else EMPTY_LABEL,
    }
    dates = {
        key: day
        for key, _ in DATE_COLUMNS
        for day in [_as_date(row.get(key))]
        if day is not None
    }
    return {
        "row": row,
        "fields": fields,
        "dates": dates,
        "resolution_hours": _resolution_hours(row),
        "is_overdue": _is_overdue_deadline(row, now),
    }


def _resolve_date_column(columns: list[dict], requested: str | None) -> str:
    date_keys = [column["key"] for column in columns if column["kind"] == "date"]
    if requested and requested in date_keys:
        return requested
    if "created_at" in date_keys:
        return "created_at"
    return date_keys[0] if date_keys else ""


def _filter_rows(
    normalized: list[dict],
    spec: AnalyticsFilterSpec,
    date_column: str,
) -> list[dict]:
    selected = {key: set(values) for key, values in spec.selected.items() if values}
    queries = {
        key: query.strip().lower()
        for key, query in spec.queries.items()
        if query and query.strip()
    }
    start = spec.period_start.isoformat() if spec.period_start else None
    end = spec.period_end.isoformat() if spec.period_end else None

    result = []
    for item in normalized:
        fields = item["fields"]
        if any(fields.get(key, "") not in values for key, values in selected.items()):
            continue
        if any(query not in fields.get(key, "").lower() for key, query in queries.items()):
            continue
        if start or end:
            day = item["dates"].get(date_column)
            if not day or (start and day < start) or (end and day > end):
                continue
        result.append(item)
    return result


def _date_bounds(normalized: list[dict], columns: list[dict]) -> dict[str, dict]:
    bounds: dict[str, dict] = {}
    for column in columns:
        if column["kind"] != "date":
            continue
        days = [
            item["dates"][column["key"]]
            for item in normalized
            if column["key"] in item["dates"]
        ]
        if days:
            bounds[column["key"]] = {"min": min(days), "max": max(days)}
    return bounds


def _count_points(counter: Counter[str], *, limit: int = TOP_CHART_LIMIT) -> list[dict]:
    return [
        {"label": label, "value": value}
        for label, value in counter.most_common(limit)
        if label
    ]


def _build_trend(
    items: list[dict],
    grouping: str,
    *,
    created_key: str = "created_at",
    closed_key: str = "time_end",
) -> dict:
    created_buckets: Counter[str] = Counter()
    closed_buckets: Counter[str] = Counter()
    for item in items:
        row = item["row"]
        created_day = _as_date(row.get(created_key))
        if created_day:
            created_buckets[_bucket_key(created_day, grouping)] += 1
        if row.get("status") == TaskStatus.DONE.value:
            closed_day = _as_date(row.get(closed_key))
            if closed_day:
                closed_buckets[_bucket_key(closed_day, grouping)] += 1
    keys = sorted(set(created_buckets) | set(closed_buckets))
    return {
        "labels": [_bucket_label(key, grouping) for key in keys],
        "created": [created_buckets.get(key, 0) for key in keys],
        "closed": [closed_buckets.get(key, 0) for key in keys],
    }


def _build_daily_detail(items: list[dict]) -> list[dict]:
    buckets: dict[str, dict] = {}
    for item in items:
        row = item["row"]
        created_day = _as_date(row.get("created_at"))
        if created_day:
            key = created_day.isoformat()
            bucket = buckets.setdefault(
                key,
                {"day": created_day, "created": 0, "closed": 0, "resolution": []},
            )
            bucket["created"] += 1
        if row.get("status") == TaskStatus.DONE.value:
            closed_day = _as_date(row.get("time_end"))
            if closed_day:
                key = closed_day.isoformat()
                bucket = buckets.setdefault(
                    key,
                    {"day": closed_day, "created": 0, "closed": 0, "resolution": []},
                )
                bucket["closed"] += 1
                hours = item["resolution_hours"]
                if hours is not None:
                    bucket["resolution"].append(hours)

    result = []
    for key in sorted(buckets):
        bucket = buckets[key]
        resolutions = bucket["resolution"]
        avg_resolution = (
            sum(resolutions) / len(resolutions) if resolutions else None
        )
        result.append(
            {
                "day": bucket["day"],
                "created": bucket["created"],
                "closed": bucket["closed"],
                "avg_reaction_hours": None,
                "avg_resolution_hours": avg_resolution,
            }
        )
    return result[-90:]


def _build_executor_trend(items: list[dict], grouping: str) -> dict:
    executor_closed: Counter[int | None] = Counter()
    for item in items:
        row = item["row"]
        if row.get("status") != TaskStatus.DONE.value:
            continue
        executor_closed[row.get("executor_id")] += 1
    top_ids = [
        user_id
        for user_id, _ in executor_closed.most_common(EXECUTOR_TREND_LIMIT)
        if user_id is not None
    ]
    if not top_ids:
        return {"labels": [], "series": []}

    bucket_keys: set[str] = set()
    series_data: dict[int, Counter[str]] = {
        user_id: Counter() for user_id in top_ids
    }
    for item in items:
        row = item["row"]
        if row.get("status") != TaskStatus.DONE.value:
            continue
        executor_id = row.get("executor_id")
        if executor_id not in series_data:
            continue
        closed_day = _as_date(row.get("time_end"))
        if not closed_day:
            continue
        key = _bucket_key(closed_day, grouping)
        bucket_keys.add(key)
        series_data[executor_id][key] += 1

    keys = sorted(bucket_keys)
    users = {
        item["row"].get("executor_id"): item["fields"]["executor"] for item in items
    }
    return {
        "labels": [_bucket_label(key, grouping) for key in keys],
        "series": [
            {
                "name": users.get(user_id, str(user_id)),
                "values": [series_data[user_id].get(key, 0) for key in keys],
            }
            for user_id in top_ids
        ],
    }


def _build_records(
    items: list[dict],
    *,
    limit: int,
    offset: int,
) -> dict:
    slice_items = items[offset : offset + limit]
    rows = []
    for item in slice_items:
        row = item["row"]
        status = row.get("status") or TaskStatus.TODO.value
        is_done = status == TaskStatus.DONE.value
        rows.append(
            {
                "id": row.get("key") or row.get("task_key") or str(row.get("id")),
                "permalink": None,
                "state": "closed" if is_done else "open",
                "state_label": STATUS_LABELS.get(status, status),
                "type": item["fields"]["type"],
                "subject": row.get("title"),
                "member": item["fields"]["executor"],
                "requested_by": item["fields"]["author"],
                "created_at": row.get("created_at"),
                "completed_at": row.get("time_end") if is_done else None,
                "resolution_hours": item["resolution_hours"],
                "reaction_hours": None,
                "is_overdue": item["is_overdue"],
            }
        )
    return {
        "items": rows,
        "total": len(items),
        "limit": limit,
        "offset": offset,
    }


class TaskAnalyticsService:
    def resolve_scope(
        self,
        *,
        scope: str,
        user_id: int,
        space_id: int | None,
    ) -> TaskAnalyticsScope:
        if scope == "personal":
            return TaskAnalyticsScope(kind="tasks_personal", owner_id=user_id)
        if scope != "space" or space_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="space_id is required for space analytics",
            )
        try:
            space = space_service.require_space(space_id)
        except SpaceNotFoundError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Space not found",
            ) from exc
        return TaskAnalyticsScope(
            kind="tasks_space",
            space_id=space_id,
            space_name=space.get("name"),
        )

    def _fetch_rows(self, scope: TaskAnalyticsScope) -> list[dict]:
        if scope.owner_id is not None:
            return task_service.list_personal_tasks_for_analytics(scope.owner_id)
        if scope.space_id is not None:
            return task_service.list_space_tasks_for_analytics(scope.space_id)
        return []

    def _load_users(self, rows: list[dict]) -> dict[int, str]:
        user_ids = set()
        for row in rows:
            for field in ("executor_id", "author_id", "responsible_id", "owner_id"):
                value = row.get(field)
                if value is not None:
                    user_ids.add(value)
        if not user_ids:
            return {}
        placeholders = ", ".join(["%s"] * len(user_ids))
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT id, name, display_name, username, email
                    FROM users
                    WHERE id IN ({placeholders})
                    """,
                    list(user_ids),
                )
                fetched = cursor.fetchall()
        return {row["id"]: _user_label(row) for row in fetched}

    def _load_types(self, rows: list[dict]) -> dict[int, str]:
        type_ids = {row.get("type_id") for row in rows if row.get("type_id")}
        if not type_ids:
            return {}
        placeholders = ", ".join(["%s"] * len(type_ids))
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"SELECT id, name FROM task_types WHERE id IN ({placeholders})",
                    list(type_ids),
                )
                fetched = cursor.fetchall()
        return {row["id"]: row["name"] for row in fetched}

    def query(
        self,
        scope: TaskAnalyticsScope,
        spec: AnalyticsFilterSpec,
        *,
        table_limit: int,
        table_offset: int,
    ) -> dict:
        now = datetime.now().replace(tzinfo=None)
        raw_rows = self._fetch_rows(scope)
        users = self._load_users(raw_rows)
        types = self._load_types(raw_rows)
        columns = _build_columns(raw_rows, types, users)
        date_column = _resolve_date_column(columns, spec.date_column)

        normalized = [
            _normalize_row(row, types=types, users=users, now=now) for row in raw_rows
        ]
        filtered = _filter_rows(normalized, spec, date_column)

        total = len(normalized)
        filtered_count = len(filtered)

        resolution_values = [
            item["resolution_hours"]
            for item in filtered
            if item["resolution_hours"] is not None
        ]
        median_resolution = median(resolution_values) if resolution_values else None

        open_count = sum(
            1
            for item in filtered
            if item["row"].get("status") != TaskStatus.DONE.value
        )
        closed_count = filtered_count - open_count
        blockers = sum(
            1
            for item in filtered
            if item["row"].get("priority") == TaskPriority.BLOCKER.value
        )
        overdue_deadline = sum(1 for item in filtered if item["is_overdue"])

        type_counter: Counter[str] = Counter()
        status_counter: Counter[str] = Counter()
        priority_counter: Counter[str] = Counter()
        executor_counter: Counter[str] = Counter()
        author_counter: Counter[str] = Counter()

        for item in filtered:
            fields = item["fields"]
            type_counter[fields["type"]] += 1
            status = item["row"].get("status") or ""
            status_counter[STATUS_LABELS.get(status, status or EMPTY_LABEL)] += 1
            priority = item["row"].get("priority")
            if priority:
                priority_counter[PRIORITY_LABELS.get(priority, priority)] += 1
            executor_counter[fields["executor"]] += 1
            author_counter[fields["author"]] += 1

        priority_ordered = [
            {"label": PRIORITY_LABELS[p.value], "value": priority_counter[PRIORITY_LABELS[p.value]]}
            for p in TASK_PRIORITIES
            if priority_counter[PRIORITY_LABELS[p.value]] > 0
        ]

        trend = {
            grouping: _build_trend(filtered, grouping) for grouping in TREND_GROUPINGS
        }
        daily_detail = _build_daily_detail(filtered)
        executor_trend = _build_executor_trend(filtered, "week")

        title = (
            "Личные задачи"
            if scope.kind == "tasks_personal"
            else f"Задачи {scope.space_name or 'пространства'}"
        )

        return {
            "dashboard_kind": scope.kind,
            "space_name": scope.space_name,
            "spreadsheet_id": "",
            "sheet_name": title,
            "fetched_at": datetime.now().astimezone().isoformat(),
            "itsm_base_url": "",
            "total_count": total,
            "filtered_count": filtered_count,
            "date_column": date_column,
            "columns": columns,
            "date_bounds": _date_bounds(normalized, columns),
            "kpi": {
                "total": filtered_count,
                "open": open_count,
                "closed": closed_count,
                "sla_ok": 0,
                "sla_known": 0,
                "confirmed": closed_count,
                "overdue_open": overdue_deadline,
                "reaction_count": 0,
                "errors": blockers,
                "waiting_open": sum(
                    1
                    for item in filtered
                    if item["row"].get("status") == TaskStatus.IN_PROGRESS.value
                ),
                "median_resolution_hours": median_resolution,
                "median_reaction_hours": None,
            },
            "charts": {
                "trend": trend,
                "type": _count_points(type_counter),
                "block": _count_points(priority_counter),
                "oiv": _count_points(executor_counter),
                "module": [],
                "problem_category": [],
                "status_group": _count_points(status_counter),
                "error_side": [],
                "oiv_waiting": [],
                "daily_detail": daily_detail,
                "status_by_category": {
                    "categories": [],
                    "closed": [],
                    "in_progress": [],
                    "waiting": [],
                },
                "solved": {"labels": [], "solved": [], "confirmed": []},
                "priority": priority_ordered,
                "executor": _count_points(executor_counter),
                "author": _count_points(author_counter),
                "executor_trend": executor_trend,
            },
            "summary": {
                "category": [],
                "block": [],
                "error_side": [],
                "oiv_waiting": [],
                "cross_matrix": {"rows": [], "cols": [], "values": []},
            },
            "records": _build_records(
                filtered,
                limit=table_limit,
                offset=table_offset,
            ),
        }


task_analytics_service = TaskAnalyticsService()
