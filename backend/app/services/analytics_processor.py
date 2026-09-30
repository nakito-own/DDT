"""Разбор листа «Заявки» и вычисляемые поля каждой заявки СТП."""

import re
from collections import Counter
from datetime import datetime
from functools import lru_cache
from zoneinfo import ZoneInfo

from app.config import settings

COL_NUMBER = "№"
COL_TICKET_ID = "ID заявки"
COL_CREATED = "Дата создания"
COL_CLOSED = "Дата закрытия"
COL_SUBJECT = "Тема"
COL_TYPE = "Тип"
COL_BLOCK = "Блок"
COL_CATEGORY = "Категория"
COL_STATUS_4ME = "Статус 4me"
COL_STATUS = "Статус"
COL_SOLVED = "Решено"
COL_USER_CONFIRMED = "Подтверждение от пользователя получено"
COL_MEMBER = ("Отвественный исполнитель", "Ответственный исполнитель")
COL_EXECUTOR_COMMENT = "Комментарий исполнителя"
COL_REQUESTED_BY = "Заявитель"
COL_OIV = "ОИВ"
COL_ORGANIZATION = "Организация"
COL_CUSTOM_FIELDS = "Кастомные поля"

COMPUTED_STATE = "Состояние"
COMPUTED_STATUS_GROUP = "Группа статуса"
COMPUTED_ERROR_SIDE = "Сторона ошибки"
COMPUTED_MODULE = "Модуль"
COMPUTED_WORK_TAKEN = "Дата взятия в работу"
COMPUTED_SLA_TARGET = "Целевой срок (SLA)"

STATE_LABELS = {"closed": "Закрыта", "open": "Открыта"}
STATUS_GROUP_LABELS = {
    "closed": "Закрыто",
    "in_progress": "В работе",
    "waiting": "Ожидание действий от клиента",
}

_COMMENT_RE = re.compile(r"^комментарий\s+(\d+)$", re.IGNORECASE)
_WAITING_PROMPT = re.compile(r"от\s+вас\s+ожида", re.IGNORECASE)
_DMY_RE = re.compile(
    r"^(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})"
    r"(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$"
)
_TIME_RE = re.compile(r"^(\d{1,2}):(\d{2})(?::(\d{2}))?")
_TRUE_VALUES = {"да", "yes", "true", "1", "y", "+"}
_FALSE_VALUES = {"нет", "no", "false", "0", "n", "-"}
_ERROR_SIDE_USER_HINTS = (
    "пусть",
    "уточнить",
    "пересоздать",
    "нет в системе",
    "пришлите",
    "скинут",
    "дайте ссылку",
    "пользовател",
)
_FILTER_IGNORED_HINTS = ("комментар", "comment", "автор", "author")
_FILTER_IGNORED_COLUMNS = {COL_CUSTOM_FIELDS.lower(), COL_NUMBER}


@lru_cache(maxsize=1)
def analytics_tz() -> ZoneInfo:
    return ZoneInfo(settings.analytics_timezone)


def analytics_now() -> datetime:
    return datetime.now(analytics_tz()).replace(tzinfo=None)


def cell_to_text(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).replace("\xa0", " ").strip()
    return text or None


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip()
    return text if text and text != "-" else None


def _parse_int(value: str | None) -> int | None:
    if not value:
        return None
    compact = value.replace(" ", "").replace(",", "")
    return int(compact) if compact.isdigit() else None


def _parse_bool(value: str | None) -> bool | None:
    if not value:
        return None
    lowered = value.lower()
    if lowered in _TRUE_VALUES:
        return True
    if lowered in _FALSE_VALUES:
        return False
    return None


def parse_datetime(value: str | None, time_value: str | None = None) -> datetime | None:
    """Дата из ячейки листа в локальном (naive) времени аналитики."""
    text = _clean(value)
    if not text:
        return None

    parsed: datetime | None = None
    match = _DMY_RE.match(text)
    if match:
        day, month, year, hour, minute, second = match.groups()
        year_num = int(year)
        if year_num < 100:
            year_num += 2000
        try:
            parsed = datetime(
                year_num,
                int(month),
                int(day),
                int(hour or 0),
                int(minute or 0),
                int(second or 0),
            )
        except ValueError:
            return None
    else:
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
        if parsed.tzinfo is not None:
            parsed = parsed.astimezone(analytics_tz()).replace(tzinfo=None)

    time_text = _clean(time_value)
    if time_text:
        time_match = _TIME_RE.match(time_text)
        if time_match:
            hour, minute, second = time_match.groups()
            parsed = parsed.replace(
                hour=int(hour), minute=int(minute), second=int(second or 0)
            )
    return parsed


def hours_between(start: datetime | None, end: datetime | None) -> float | None:
    if start is None or end is None:
        return None
    return round((end - start).total_seconds() / 3600, 2)


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _find_header_row(rows: list[list[str | None]]) -> int | None:
    for index, row in enumerate(rows):
        labels = {cell.lower() for cell in row if cell}
        if COL_TICKET_ID.lower() in labels and (
            COL_STATUS.lower() in labels or COL_SUBJECT.lower() in labels
        ):
            return index
    return None


def _is_ticket_row(record: dict[str, str | None]) -> bool:
    ticket_id = _lookup(record, COL_TICKET_ID) or ""
    if ticket_id.isdigit() and len(ticket_id) >= 5:
        return True
    number = _lookup(record, COL_NUMBER) or ""
    return bool(
        number.isdigit()
        and (_lookup(record, COL_SUBJECT) or _lookup(record, COL_STATUS))
    )


def parse_applications(values: list[list[object]]) -> list[dict[str, str | None]]:
    rows = [[cell_to_text(item) for item in row] for row in values]
    header_index = _find_header_row(rows)
    if header_index is None:
        return []

    keys: list[str] = []
    seen: dict[str, int] = {}
    for index, label in enumerate(rows[header_index]):
        base = label or f"column_{index + 1}"
        count = seen.get(base, 0) + 1
        seen[base] = count
        keys.append(base if count == 1 else f"{base}_{count}")

    records: list[dict[str, str | None]] = []
    for raw in rows[header_index + 1 :]:
        record = {
            key: raw[index] if index < len(raw) else None
            for index, key in enumerate(keys)
        }
        if any(record.values()) and _is_ticket_row(record):
            records.append(record)
    return records


def _lookup(record: dict[str, str | None], *names: str) -> str | None:
    return _Row(record).raw(*names)


class _Row:
    """Строка листа с поиском колонок без учёта регистра."""

    def __init__(self, record: dict[str, str | None]) -> None:
        self._values = {key.strip().lower(): value for key, value in record.items()}

    def raw(self, *names: str) -> str | None:
        for name in names:
            value = self._values.get(name.lower())
            if value:
                return value
        return None

    def get(self, *names: str) -> str | None:
        return _clean(self.raw(*names))

    def comment_indices(self) -> list[int]:
        indices = []
        for key in self._values:
            match = _COMMENT_RE.match(key)
            if match:
                indices.append(int(match.group(1)))
        return sorted(indices)


def _parse_custom_fields(text: str | None) -> dict[str, str]:
    result: dict[str, str] = {}
    if not text:
        return result
    for line in text.split("\n"):
        line = line.strip()
        if ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip()
    return result


def _extract_module(url: str | None) -> str:
    if not url:
        return "Не указан"
    lowered = url.lower()
    if "landscaping" in lowered:
        return "landscaping"
    if "mydistrict" in lowered:
        return "mydistrict"
    if "f_work" in lowered or "/work" in lowered:
        return "Работы"
    if "task" in lowered or "задач" in lowered:
        return "Задачи"
    if "newsmart.mos.ru" in lowered or "smart.mos.ru" in lowered:
        return "smart.mos.ru"
    if lowered.startswith("http"):
        return "Прочее"
    return "Не указан"


def _comment_at(row: _Row, index: int) -> datetime | None:
    return parse_datetime(
        row.raw(f"Дата комментария {index}"),
        row.raw(f"Время комментария {index}"),
    )


def _comment_timeline(row: _Row, indices: list[int]) -> list[tuple[datetime, str]]:
    comments = []
    for index in indices:
        text = row.get(f"Комментарий {index}")
        if not text:
            continue
        at = _comment_at(row, index)
        if at is None:
            continue
        comments.append((at, text))
    return sorted(comments, key=lambda item: item[0])


def _status_group(state: str, status_4me: str | None, status: str | None) -> str:
    status_text = (status or "").lower()
    if state == "closed" or status_text == "завершено":
        return "closed"
    if status_4me == "waiting_for_customer" or status_text.startswith("ожидание"):
        return "waiting"
    return "in_progress"


def _infer_error_side(
    row: _Row,
    text_lower: str,
    *,
    status_4me: str | None,
    status: str | None,
    member: str | None,
    ticket_type: str | None,
) -> str:
    executor_comment = (row.get(COL_EXECUTOR_COMMENT) or "").lower()
    member = member or ""

    if "ецп" in text_lower or "ecp" in text_lower:
        return "ЕЦП"
    if any(hint in text_lower for hint in ("цифровой двойник", "цд 2", "цд2", " аис «ц")):
        return "ЦД"
    if status_4me == "waiting_for_customer" or "ожидание действий от клиента" in (
        status or ""
    ).lower():
        return "Пользователь"
    if any(hint in executor_comment for hint in _ERROR_SIDE_USER_HINTS):
        return "Пользователь"
    if member.startswith("ДИТ"):
        return "ДИТ"
    if ticket_type == "Доступ":
        return "ЕЦП"
    if ticket_type in ("Ошибка", "Доработка"):
        return "КРР МР"
    if member.startswith("БС"):
        return "КРР МР"
    if ticket_type == "Консультация":
        return "Пользователь"
    return "Не определено"


def _waiting_metrics(
    comments: list[tuple[datetime, str]],
    status_group: str,
    completed_at: datetime | None,
) -> dict:
    waiting_start: datetime | None = None
    for at, text in comments:
        if _WAITING_PROMPT.search(text):
            waiting_start = at
            break
    if waiting_start is None and status_group == "waiting" and comments:
        waiting_start = comments[-1][0]

    client_response_hours = None
    if waiting_start is not None:
        end: datetime | None = None
        for at, text in comments:
            if at <= waiting_start or _WAITING_PROMPT.search(text):
                continue
            end = at
            break
        if end is None and status_group != "waiting" and completed_at:
            end = completed_at
        client_response_hours = hours_between(waiting_start, end)

    return {
        "waiting_started_at": _iso(waiting_start),
        "client_response_hours": client_response_hours,
        "has_waiting_episode": waiting_start is not None or status_group == "waiting",
    }


def _text_blob(row: _Row, comment_indices: list[int]) -> str:
    parts = [
        row.get(COL_SUBJECT),
        row.get(COL_EXECUTOR_COMMENT),
        row.get(COL_CUSTOM_FIELDS),
        *(row.get(f"Комментарий {index}") for index in comment_indices),
    ]
    return " ".join(part for part in parts if part).lower()


def build_ticket(
    record: dict[str, str | None],
    filter_keys: list[str],
    date_keys: list[str],
) -> dict:
    row = _Row(record)
    ticket_id = row.get(COL_TICKET_ID) or row.get(COL_NUMBER) or ""
    custom = _parse_custom_fields(row.raw(COL_CUSTOM_FIELDS))
    resource = custom.get("resource")
    comment_indices = row.comment_indices()
    comments = _comment_timeline(row, comment_indices)

    created_at = parse_datetime(row.raw(COL_CREATED))
    completed_at = parse_datetime(row.raw(COL_CLOSED))
    comment1_at = _comment_at(row, 1)
    comment2_at = _comment_at(row, 2)
    sla_target = parse_datetime(custom.get("close_time"))

    status_4me = row.get(COL_STATUS_4ME)
    status = row.get(COL_STATUS)
    member = row.get(*COL_MEMBER)
    ticket_type = row.get(COL_TYPE)
    state = "closed" if status_4me == "completed" else "open"
    status_group = _status_group(state, status_4me, status)

    resolution_hours = hours_between(created_at, completed_at)
    if resolution_hours is not None and resolution_hours < 0:
        resolution_hours = None
    reaction_hours = hours_between(comment1_at, comment2_at)
    if reaction_hours is not None and reaction_hours < 0:
        reaction_hours = None
    sla_met = completed_at <= sla_target if sla_target and completed_at else None

    error_side = _infer_error_side(
        row,
        _text_blob(row, comment_indices),
        status_4me=status_4me,
        status=status,
        member=member,
        ticket_type=ticket_type,
    )
    module = _extract_module(resource)

    fields = {key: record.get(key) or "" for key in filter_keys}
    fields[COMPUTED_STATE] = STATE_LABELS[state]
    fields[COMPUTED_STATUS_GROUP] = STATUS_GROUP_LABELS[status_group]
    fields[COMPUTED_ERROR_SIDE] = error_side
    fields[COMPUTED_MODULE] = module

    dates: dict[str, str] = {}
    for key in date_keys:
        parsed = parse_datetime(record.get(key))
        if parsed:
            dates[key] = parsed.date().isoformat()
    if comment2_at:
        dates[COMPUTED_WORK_TAKEN] = comment2_at.date().isoformat()
    if sla_target:
        dates[COMPUTED_SLA_TARGET] = sla_target.date().isoformat()

    return {
        "id": ticket_id,
        "number": row.get(COL_NUMBER),
        "permalink": f"{settings.analytics_itsm_base_url}{ticket_id}" if ticket_id else None,
        "state": state,
        "status": status,
        "status_4me": status_4me,
        "status_group": status_group,
        "type": ticket_type,
        "block": row.get(COL_BLOCK),
        "problem_category": row.get(COL_CATEGORY),
        "subject": row.get(COL_SUBJECT),
        "solved": row.get(COL_SOLVED),
        "user_confirmed": row.get(COL_USER_CONFIRMED),
        "member": member,
        "requested_by": row.get(COL_REQUESTED_BY),
        "oiv": row.get(COL_OIV),
        "organization": row.get(COL_ORGANIZATION),
        "error_side": error_side,
        "module": module,
        "resource": resource,
        "created_at": _iso(created_at),
        "work_taken_at": _iso(comment2_at),
        "completed_at": _iso(completed_at),
        "sla_target": _iso(sla_target),
        "resolution_hours": resolution_hours,
        "reaction_hours": reaction_hours,
        "sla_met": sla_met,
        "comment_count": sum(
            1 for index in comment_indices if row.get(f"Комментарий {index}")
        ),
        **_waiting_metrics(comments, status_group, completed_at),
        "fields": fields,
        "dates": dates,
    }


def _is_filter_ignored(key: str) -> bool:
    lowered = key.lower()
    if lowered in _FILTER_IGNORED_COLUMNS:
        return True
    return any(hint in lowered for hint in _FILTER_IGNORED_HINTS)


def _header_looks_date(key: str) -> bool:
    lowered = key.lower()
    return any(hint in lowered for hint in ("дата", "date", "обновл", "updated"))


def _column_kind(key: str, nonempty: list[str]) -> str:
    if not nonempty:
        return "text"
    date_hits = sum(1 for value in nonempty if parse_datetime(value))
    date_ratio = date_hits / len(nonempty)
    if (_header_looks_date(key) and date_ratio >= 0.25) or date_ratio >= 0.7:
        return "date"
    distinct = set(nonempty)
    if len(distinct) <= 4 and all(_parse_bool(value) is not None for value in nonempty):
        return "boolean"
    avg_len = sum(len(value) for value in nonempty) / len(nonempty)
    if avg_len >= 70:
        return "text"
    if len(distinct) <= 40 and len(distinct) / len(nonempty) <= 0.55:
        return "enum"
    if all(_parse_int(value) is not None for value in nonempty[:80]):
        return "number"
    return "text"


def _column_options(values: list[str]) -> list[dict]:
    counts = Counter(value for value in values if value)
    options = [
        {"key": label, "label": label, "value": count}
        for label, count in counts.most_common()
    ]
    empty = sum(1 for value in values if not value)
    if empty:
        options.append({"key": "", "label": "Пусто", "value": empty})
    return options


def _infer_sheet_columns(records: list[dict[str, str | None]]) -> list[dict]:
    keys: list[str] = []
    for record in records:
        for key in record:
            if key not in keys:
                keys.append(key)

    columns = []
    for key in keys:
        if _is_filter_ignored(key):
            continue
        values = [record.get(key) or "" for record in records]
        nonempty = [value for value in values if value]
        if not nonempty and key.startswith("column_"):
            continue
        kind = _column_kind(key, nonempty)
        columns.append(
            {
                "key": key,
                "label": key,
                "kind": kind,
                "computed": False,
                "options": [] if kind == "date" else _column_options(values),
            }
        )
    return columns


def _computed_columns(tickets: list[dict]) -> list[dict]:
    columns = [
        {
            "key": key,
            "label": key,
            "kind": "enum",
            "computed": True,
            "options": _column_options([ticket["fields"][key] for ticket in tickets]),
        }
        for key in (
            COMPUTED_STATE,
            COMPUTED_STATUS_GROUP,
            COMPUTED_ERROR_SIDE,
            COMPUTED_MODULE,
        )
    ]
    columns.extend(
        {"key": key, "label": key, "kind": "date", "computed": True, "options": []}
        for key in (COMPUTED_WORK_TAKEN, COMPUTED_SLA_TARGET)
    )
    return columns


def build_dataset(values: list[list[object]]) -> dict:
    records = parse_applications(values)
    sheet_columns = _infer_sheet_columns(records)
    filter_keys = [column["key"] for column in sheet_columns if column["kind"] != "date"]
    date_keys = [column["key"] for column in sheet_columns if column["kind"] == "date"]
    tickets = [build_ticket(record, filter_keys, date_keys) for record in records]
    return {
        "tickets": tickets,
        "columns": sheet_columns + _computed_columns(tickets),
    }
