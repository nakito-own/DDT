from collections import Counter
from datetime import date, datetime, timedelta

_HEADER_KEYS = {
    "№": "number",
    "N": "number",
    "ID заявки": "ticket_id",
    "Id заявки": "ticket_id",
    "Дата создания": "created_at",
    "Дата закрытия": "closed_at",
    "Тема": "subject",
    "Комментарий 1": "comment",
    "Комментарий": "comment",
    "Тип": "type",
    "Блок": "block",
    "Категория": "category",
    "Статус 4me": "status_4me",
    "Статус": "status",
    "Решено": "resolved",
    "Подтверждение от пользователя получено": "user_confirmed",
}

_DATE_FORMATS = ("%d-%m-%Y", "%d.%m.%Y", "%Y-%m-%d", "%d/%m/%Y")
_TRUE_VALUES = {"да", "yes", "true", "1", "y", "+"}
_FALSE_VALUES = {"нет", "no", "false", "0", "n", "-"}
_MONTHS_RU = (
    "янв",
    "фев",
    "мар",
    "апр",
    "май",
    "июн",
    "июл",
    "авг",
    "сен",
    "окт",
    "ноя",
    "дек",
)
_STATUS_ORDER = (
    "Назначено",
    "В процессе",
    "Ожидание действий от клиента",
    "Завершено",
)


def cell_to_text(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).replace("\xa0", " ").strip()
    return text or None


def _cells(row: list[object]) -> list[str | None]:
    return [cell_to_text(item) for item in row]


def _parse_int(value: str | None) -> int | None:
    if not value:
        return None
    compact = value.replace(" ", "").replace("\u00a0", "").replace(",", "")
    if compact.isdigit():
        return int(compact)
    return None


def _parse_date(value: str | None) -> date | None:
    if not value:
        return None
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            continue
    return None


def _parse_bool(value: str | None) -> bool | None:
    if not value:
        return None
    lowered = value.lower()
    if lowered in _TRUE_VALUES:
        return True
    if lowered in _FALSE_VALUES:
        return False
    return None


def _normalize_header(value: str | None, index: int) -> str:
    if not value:
        return f"column_{index + 1}"
    return value


def _find_header_row(rows: list[list[str | None]]) -> int | None:
    for index, row in enumerate(rows):
        labels = {cell.lower() for cell in row if cell}
        if "id заявки" in labels and ("статус" in labels or "тема" in labels):
            return index
    return None


def _find_kpi_block(
    rows: list[list[str | None]], header_index: int
) -> dict[str, int]:
    kpis: dict[str, int] = {}
    search_to = header_index if header_index >= 0 else len(rows)
    for index in range(search_to):
        labels = rows[index]
        if "Всего" not in labels:
            continue
        values: list[str | None] | None = None
        for following in rows[index + 1 : search_to]:
            if any(cell for cell in following):
                values = following
                break
        if values is None:
            continue
        width = max(len(labels), len(values))
        for col in range(width):
            label = labels[col] if col < len(labels) else None
            number = _parse_int(values[col] if col < len(values) else None)
            if label and number is not None:
                kpis[label] = number
        if kpis:
            break
    return kpis


def _status_bucket(status: str | None, status_4me: str | None) -> str:
    text = (status or "").lower()
    code = (status_4me or "").lower().replace(" ", "_")
    if "заверш" in text or code == "completed":
        return "Завершено"
    if "ожидан" in text or "waiting_for_customer" in code:
        return "Ожидание действий от клиента"
    if "процесс" in text or "in_progress" in code or code == "progress":
        return "В процессе"
    if "назнач" in text or code in {"assigned", "waiting_for_assignment"}:
        return "Назначено"
    return status or status_4me or "Другое"


def _topic_from_subject(subject: str | None) -> str | None:
    if not subject:
        return None
    compact = " ".join(subject.split())
    prefix = "КРР МР."
    if compact.upper().startswith(prefix):
        rest = compact[len(prefix) :].strip(" .")
        return rest or compact
    if "." in compact and len(compact) > 24:
        return compact.split(".", 1)[0].strip()
    return compact


def _week_label(value: date) -> tuple[date, str]:
    start = value - timedelta(days=value.weekday())
    end = start + timedelta(days=6)
    if start.month == end.month:
        label = f"{start.day}–{end.day} {_MONTHS_RU[start.month - 1]}"
    else:
        label = (
            f"{start.day} {_MONTHS_RU[start.month - 1]} – "
            f"{end.day} {_MONTHS_RU[end.month - 1]}"
        )
    return start, label


def _count_points(values: list[str | None], *, limit: int | None = None) -> list[dict]:
    counter = Counter(value for value in values if value)
    items = counter.most_common(limit)
    return [{"label": label, "value": count} for label, count in items]


def _is_ticket_row(row: dict[str, str | None]) -> bool:
    ticket_id = _lookup(row, "ticket_id", "ID заявки") or ""
    if ticket_id.isdigit() and len(ticket_id) >= 5:
        return True
    number = _lookup(row, "number", "№") or ""
    return bool(
        number.isdigit()
        and (_lookup(row, "subject", "Тема") or _lookup(row, "status", "Статус"))
    )


def parse_applications(values: list[list[object]]) -> dict:
    rows = [_cells(row) for row in values]
    header_index = _find_header_row(rows)
    if header_index is None:
        return {
            "sheet_kpis": {},
            "applications": [],
            "empty_row_count": 0,
        }

    sheet_kpis = _find_kpi_block(rows, header_index)
    header_row = rows[header_index]
    keys: list[str] = []
    seen: dict[str, int] = {}
    for index, label in enumerate(header_row):
        base = _normalize_header(label, index)
        count = seen.get(base, 0) + 1
        seen[base] = count
        keys.append(base if count == 1 else f"{base}_{count}")

    applications: list[dict] = []
    empty_row_count = 0
    for raw in rows[header_index + 1 :]:
        padded = raw + [None] * (len(keys) - len(raw))
        record = {
            keys[index]: padded[index] if index < len(padded) else None
            for index in range(len(keys))
        }
        if not any(record.values()):
            empty_row_count += 1
            continue
        if not _is_ticket_row(record):
            continue
        applications.append(record)

    return {
        "sheet_kpis": sheet_kpis,
        "applications": applications,
        "empty_row_count": empty_row_count,
    }


def _lookup(record: dict[str, str | None], *names: str) -> str | None:
    lower = {key.lower(): key for key in record}
    expanded: list[str] = []
    for name in names:
        expanded.append(name)
        for label, english in _HEADER_KEYS.items():
            if name in {label, english}:
                expanded.extend((label, english))
    seen: set[str] = set()
    for name in expanded:
        token = name.lower()
        if token in seen:
            continue
        seen.add(token)
        key = lower.get(token)
        if key is None:
            continue
        value = record.get(key)
        if value:
            return value
    return None


def _header_looks_comment(key: str) -> bool:
    lowered = key.lower()
    return "комментар" in lowered or "comment" in lowered


def _header_looks_author(key: str) -> bool:
    lowered = key.lower()
    return "автор" in lowered or "author" in lowered


def _header_looks_date(key: str) -> bool:
    lowered = key.lower()
    return any(
        hint in lowered
        for hint in ("дата", "date", "обновл", "updated", "modified")
    )


def infer_columns(records: list[dict[str, str | None]]) -> list[dict]:
    keys: list[str] = []
    seen: set[str] = set()
    for record in records:
        for key in record:
            if key in seen:
                continue
            seen.add(key)
            keys.append(key)

    columns: list[dict] = []
    total = max(len(records), 1)
    for key in keys:
        values = [record.get(key) for record in records]
        nonempty = [value for value in values if value]
        if not nonempty and key.startswith("column_"):
            continue
        if _header_looks_comment(key) or _header_looks_author(key):
            continue

        kind = "text"
        if nonempty:
            date_hits = sum(1 for value in nonempty if _parse_date(value))
            date_ratio = date_hits / len(nonempty)
            bool_hits = sum(
                1 for value in nonempty if _parse_bool(value) is not None
            )
            distinct = set(nonempty)
            avg_len = sum(len(value) for value in nonempty) / len(nonempty)
            uniqueness = len(distinct) / len(nonempty)

            if (_header_looks_date(key) and date_ratio >= 0.25) or date_ratio >= 0.7:
                kind = "date"
            elif bool_hits == len(nonempty) and len(distinct) <= 4:
                kind = "boolean"
            elif avg_len >= 70:
                kind = "text"
            elif len(distinct) <= 40 and uniqueness <= 0.55:
                kind = "enum"
            elif all(_parse_int(value) is not None for value in nonempty[:80]):
                kind = "number"
            else:
                kind = "text"

        counts = Counter(nonempty)
        empty_count = total - len(nonempty)
        options: list[dict] = [
            {"key": label, "label": label, "value": count}
            for label, count in counts.most_common()
        ]
        if empty_count and kind in {"enum", "boolean"}:
            options.append({"key": "", "label": "Пусто", "value": empty_count})

        columns.append(
            {
                "key": key,
                "label": key,
                "kind": kind,
                "options": options if kind in {"enum", "boolean"} else [],
            }
        )
    return columns


def _ticket_payload(
    record: dict[str, str | None],
    date_keys: set[str],
) -> dict:
    created = _parse_date(_lookup(record, "created_at", "Дата создания"))
    closed = _parse_date(_lookup(record, "closed_at", "Дата закрытия"))
    status = _lookup(record, "status", "Статус")
    status_4me = _lookup(record, "status_4me", "Статус 4me")
    subject = _lookup(record, "subject", "Тема")
    dates = {}
    for key in date_keys:
        parsed = _parse_date(record.get(key))
        if parsed:
            dates[key] = parsed.isoformat()
    return {
        "number": _lookup(record, "number", "№"),
        "ticket_id": _lookup(record, "ticket_id", "ID заявки")
        or _lookup(record, "number", "№")
        or "",
        "created_at": created.isoformat() if created else None,
        "closed_at": closed.isoformat() if closed else None,
        "subject": subject,
        "type": _lookup(record, "type", "Тип"),
        "block": _lookup(record, "block", "Блок"),
        "category": _lookup(record, "category", "Категория"),
        "status": status,
        "status_4me": status_4me,
        "resolved": _parse_bool(_lookup(record, "resolved", "Решено")),
        "user_confirmed": _parse_bool(
            _lookup(record, "user_confirmed", "Подтверждение от пользователя получено")
        ),
        "status_bucket": _status_bucket(status, status_4me),
        "topic": _topic_from_subject(subject),
        "fields": {key: value for key, value in record.items() if value is not None},
        "dates": dates,
    }


def build_dashboard(parsed: dict) -> dict:
    records: list[dict[str, str | None]] = parsed["applications"]
    columns = infer_columns(records)
    date_keys = {column["key"] for column in columns if column["kind"] == "date"}
    tickets = [_ticket_payload(record, date_keys) for record in records]
    buckets = [ticket["status_bucket"] for ticket in tickets]
    bucket_counts = Counter(buckets)

    assigned = bucket_counts.get("Назначено", 0)
    in_progress = bucket_counts.get("В процессе", 0)
    waiting = bucket_counts.get("Ожидание действий от клиента", 0)
    completed = bucket_counts.get("Завершено", 0)
    resolved = sum(1 for ticket in tickets if ticket["resolved"] is True)
    confirmed = sum(1 for ticket in tickets if ticket["user_confirmed"] is True)

    close_days: list[int] = []
    for record in records:
        created = _parse_date(record.get("created_at"))
        closed = _parse_date(record.get("closed_at"))
        if created and closed and closed >= created:
            close_days.append((closed - created).days)
    avg_close = round(sum(close_days) / len(close_days), 1) if close_days else None

    weekly: Counter[date] = Counter()
    weekly_labels: dict[date, str] = {}
    for record in records:
        created = _parse_date(record.get("created_at"))
        if created is None:
            continue
        start, label = _week_label(created)
        weekly[start] += 1
        weekly_labels[start] = label

    status_series = [
        {"label": label, "value": bucket_counts.get(label, 0)}
        for label in _STATUS_ORDER
        if bucket_counts.get(label, 0)
    ]
    other_status = [
        {"label": label, "value": count}
        for label, count in bucket_counts.most_common()
        if label not in _STATUS_ORDER
    ]
    status_series.extend(other_status)

    sheet_kpis = parsed.get("sheet_kpis") or {}
    return {
        "kpis": {
            "total": len(tickets),
            "assigned": assigned,
            "in_progress": in_progress,
            "waiting_customer": waiting,
            "completed": completed,
            "open": assigned + in_progress + waiting,
            "resolved": resolved,
            "unresolved": len(tickets) - resolved,
            "user_confirmed": confirmed,
            "avg_close_days": avg_close,
            "sheet_total": sheet_kpis.get("Всего"),
            "sheet_waiting_left": sheet_kpis.get("Осталось"),
        },
        "series": {
            "status": status_series,
            "type": _count_points([ticket["type"] for ticket in tickets]),
            "block": _count_points([ticket["block"] for ticket in tickets]),
            "category": _count_points(
                [ticket["category"] for ticket in tickets], limit=12
            ),
            "topics": _count_points(
                [ticket["topic"] for ticket in tickets],
                limit=12,
            ),
            "created_weekly": [
                {"label": weekly_labels[start], "value": weekly[start]}
                for start in sorted(weekly)
            ],
        },
        "recent": sorted(
            tickets,
            key=lambda item: (item["created_at"] or "", item["ticket_id"]),
            reverse=True,
        )[:12],
        "applications": tickets,
        "columns": columns,
    }
