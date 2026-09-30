"""Фильтрация и агрегации на сервере — данные не уходят целиком на клиент."""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from statistics import median
from typing import Any

STATUS_GROUP_LABELS = {
    "closed": "Закрыто",
    "in_progress": "В работе",
    "waiting": "Ожидание действий от клиента",
}
STATUS_GROUP_ORDER = ["in_progress", "waiting", "closed"]

STP_MULTI_FILTER_KEYS = [
    "state", "status", "status4me", "type", "block", "problemCategory",
    "member", "requestedBy", "oiv", "organization", "module", "solved",
    "userConfirmed", "errorSide", "statusGroup",
]

FOURME_FILTER_KEYS = [
    "statusLabel", "categoryLabel", "impactLabel", "serviceShort",
    "memberShort", "source", "organization", "completionReasonLabel",
    "team", "agileColumn",
]


def _avg(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def _hours_between(start: str | None, end: str | None) -> float | None:
    if not start or not end:
        return None
    try:
        start_ts = datetime.fromisoformat(str(start).replace("Z", "+00:00"))
        end_ts = datetime.fromisoformat(str(end).replace("Z", "+00:00"))
        if start_ts.tzinfo is not None:
            start_ts = start_ts.replace(tzinfo=None)
        if end_ts.tzinfo is not None:
            end_ts = end_ts.replace(tzinfo=None)
        return round((end_ts - start_ts).total_seconds() / 3600, 2)
    except ValueError:
        return None


def _waiting_hours(record: dict[str, Any]) -> float | None:
    if record.get("statusGroup") == "waiting" and record.get("waitingStartedAt"):
        return _hours_between(record["waitingStartedAt"], datetime.now().isoformat())
    return record.get("clientResponseHours")


def aggregate_oiv_waiting(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups: dict[str, dict[str, Any]] = {}

    for record in records:
        has_episode = record.get("hasWaitingEpisode") or record.get("statusGroup") == "waiting"
        if not has_episode:
            continue

        hours = _waiting_hours(record)
        if hours is None and record.get("statusGroup") != "waiting":
            continue

        oiv = str(record.get("oiv") or "—")
        group = groups.setdefault(oiv, {
            "name": oiv,
            "ids": [],
            "waitingHours": [],
            "openWaiting": 0,
            "episodeCount": 0,
        })
        group["ids"].append(record.get("id"))
        group["episodeCount"] += 1
        if record.get("statusGroup") == "waiting":
            group["openWaiting"] += 1
        if hours is not None:
            group["waitingHours"].append(hours)

    rows = []
    for group in groups.values():
        hours = group["waitingHours"]
        rows.append({
            "name": group["name"],
            "episodeCount": group["episodeCount"],
            "openWaiting": group["openWaiting"],
            "avgWaitingHours": _avg(hours),
            "medianWaitingHours": median(hours) if hours else None,
            "maxWaitingHours": max(hours) if hours else None,
            "exampleIds": group["ids"][:8],
        })

    return sorted(
        rows,
        key=lambda row: (-(row["avgWaitingHours"] or 0), -row["openWaiting"], -row["episodeCount"]),
    )


def _normalize_stp_record(record: dict[str, Any]) -> dict[str, Any]:
    state = "closed" if record.get("state") == "closed" else "open"
    return {
        **record,
        "state": state,
        "stateLabel": "закрыта" if state == "closed" else "открыта",
    }


def _is_overdue(record: dict[str, Any]) -> bool:
    if record.get("state") != "open" or not record.get("slaTarget"):
        return False
    try:
        target = datetime.fromisoformat(str(record["slaTarget"]).replace("Z", "+00:00"))
        now = datetime.now(target.tzinfo) if target.tzinfo else datetime.now()
        return now > target
    except ValueError:
        return False


def filter_records(
    records: list[dict[str, Any]],
    *,
    date_field: str,
    date_from: str | None,
    date_to: str | None,
    multi: dict[str, list[str]],
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for record in records:
        skip = False
        for key, values in multi.items():
            if str(record.get(key) or "") not in values:
                skip = True
                break
        if skip:
            continue

        if date_from or date_to:
            val = record.get(date_field)
            if not val:
                continue
            day = str(val)[:10]
            if date_from and day < date_from:
                continue
            if date_to and day > date_to:
                continue

        result.append(record)
    return result


def _week_start(iso_day: str) -> str:
    d = date.fromisoformat(iso_day)
    weekday = d.weekday()
    start = d - timedelta(days=weekday)
    return start.isoformat()


def _period_key(iso_date: str | None, group_by: str) -> str | None:
    if not iso_date:
        return None
    day = str(iso_date)[:10]
    if group_by == "day":
        return day
    if group_by == "month":
        return day[:7]
    return _week_start(day)


def _format_period_label(key: str, group_by: str) -> str:
    if group_by == "month":
        y, m = key.split("-")
        return f"{m}.{y}"
    if group_by == "day":
        y, m, d = key.split("-")
        return f"{d}.{m}.{y[2:]}"
    start = date.fromisoformat(key)
    end = start + timedelta(days=6)
    return f"{start.strftime('%d.%m')}–{end.strftime('%d.%m')}"


def _enumerate_periods(min_key: str, max_key: str, group_by: str) -> list[str]:
    if group_by == "month":
        sy, sm = map(int, min_key.split("-"))
        ey, em = map(int, max_key.split("-"))
        result: list[str] = []
        y, m = sy, sm
        while y < ey or (y == ey and m <= em):
            result.append(f"{y}-{m:02d}")
            m += 1
            if m > 12:
                m = 1
                y += 1
        return result

    step = 7 if group_by == "week" else 1
    cursor = date.fromisoformat(min_key)
    end = date.fromisoformat(max_key)
    result = []
    while cursor <= end:
        key = _week_start(cursor.isoformat()) if group_by == "week" else cursor.isoformat()
        if not result or result[-1] != key:
            result.append(key)
        cursor += timedelta(days=step)
    return result


def build_trend_buckets(
    records: list[dict[str, Any]],
    group_by: str,
) -> dict[str, list[Any]]:
    buckets: dict[str, dict[str, int]] = {}
    for record in records:
        created_key = _period_key(record.get("createdAt"), group_by)
        if created_key:
            buckets.setdefault(created_key, {"created": 0, "closed": 0})
            buckets[created_key]["created"] += 1
        if record.get("completedAt"):
            closed_key = _period_key(record.get("completedAt"), group_by)
            if closed_key:
                buckets.setdefault(closed_key, {"created": 0, "closed": 0})
                buckets[closed_key]["closed"] += 1

    keys = sorted(buckets)
    if not keys:
        return {"labels": [], "created": [], "closed": []}

    full_keys = _enumerate_periods(keys[0], keys[-1], group_by)
    return {
        "labels": [_format_period_label(k, group_by) for k in full_keys],
        "created": [buckets.get(k, {}).get("created", 0) for k in full_keys],
        "closed": [buckets.get(k, {}).get("closed", 0) for k in full_keys],
    }


def count_by(records: list[dict[str, Any]], key: str) -> list[list[Any]]:
    counts: dict[str, int] = defaultdict(int)
    for record in records:
        counts[str(record.get(key) or "—")] += 1
    return [[name, count] for name, count in sorted(counts.items(), key=lambda x: -x[1])]


def count_by_status_group(records: list[dict[str, Any]]) -> list[list[Any]]:
    counts: dict[str, int] = defaultdict(int)
    for record in records:
        counts[str(record.get("statusGroup") or "unknown")] += 1

    ordered = [
        [STATUS_GROUP_LABELS[k], counts[k]]
        for k in STATUS_GROUP_ORDER
        if counts.get(k)
    ]
    extra = sorted(
        (
            (k, c)
            for k, c in counts.items()
            if k not in STATUS_GROUP_ORDER
        ),
        key=lambda x: -x[1],
    )
    for key, count in extra:
        ordered.append([STATUS_GROUP_LABELS.get(key, key), count])
    return ordered


def aggregate_groups(
    records: list[dict[str, Any]],
    group_key: str,
    *,
    with_error_side: bool = True,
) -> list[dict[str, Any]]:
    total = len(records) or 1
    groups: dict[str, dict[str, Any]] = {}

    for record in records:
        name = str(record.get(group_key) or "—")
        group = groups.setdefault(name, {
            "name": name,
            "ids": [],
            "closed": 0,
            "inProgress": 0,
            "waiting": 0,
            "resolutionHours": [],
            "reactionHours": [],
            "errorSides": defaultdict(int),
        })
        group["ids"].append(record.get("id"))
        sg = record.get("statusGroup")
        if sg == "closed":
            group["closed"] += 1
        elif sg == "waiting":
            group["waiting"] += 1
        else:
            group["inProgress"] += 1
        if record.get("resolutionHours") is not None:
            group["resolutionHours"].append(record["resolutionHours"])
        if record.get("reactionHours") is not None:
            group["reactionHours"].append(record["reactionHours"])
        if with_error_side:
            group["errorSides"][str(record.get("errorSide") or "—")] += 1

    rows = []
    for group in groups.values():
        error_side = None
        if with_error_side and group["errorSides"]:
            error_side = max(group["errorSides"], key=group["errorSides"].get)
        rows.append({
            "name": group["name"],
            "count": len(group["ids"]),
            "share": len(group["ids"]) / total * 100,
            "avgResolution": _avg(group["resolutionHours"]),
            "avgReaction": _avg(group["reactionHours"]),
            "closed": group["closed"],
            "inProgress": group["inProgress"],
            "waiting": group["waiting"],
            "errorSide": error_side,
            "exampleIds": group["ids"][:8],
        })
    return sorted(rows, key=lambda r: -r["count"])


def build_daily_detail(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    days: dict[str, dict[str, Any]] = {}
    for record in records:
        if record.get("createdAt"):
            d = str(record["createdAt"])[:10]
            days.setdefault(d, {"day": d, "created": 0, "closed": 0, "reactions": []})
            days[d]["created"] += 1
        if record.get("completedAt"):
            d = str(record["completedAt"])[:10]
            days.setdefault(d, {"day": d, "created": 0, "closed": 0, "reactions": []})
            days[d]["closed"] += 1
        if record.get("createdAt") and record.get("reactionHours") is not None:
            d = str(record["createdAt"])[:10]
            days.setdefault(d, {"day": d, "created": 0, "closed": 0, "reactions": []})
            days[d]["reactions"].append(record["reactionHours"])
    return [days[d] for d in sorted(days)]


def build_status_by_category(records: list[dict[str, Any]]) -> dict[str, Any]:
    top = count_by(records, "problemCategory")[:8]
    categories = [row[0] for row in top]
    closed, in_progress, waiting = [], [], []
    for cat in categories:
        subset = [r for r in records if str(r.get("problemCategory") or "—") == cat]
        closed.append(sum(1 for r in subset if r.get("statusGroup") == "closed"))
        in_progress.append(sum(1 for r in subset if r.get("statusGroup") == "in_progress"))
        waiting.append(sum(1 for r in subset if r.get("statusGroup") == "waiting"))
    return {"categories": categories, "closed": closed, "inProgress": in_progress, "waiting": waiting}


def build_cross_matrix(
    records: list[dict[str, Any]],
    row_key: str,
    col_key: str,
) -> dict[str, Any]:
    rows = sorted({str(r.get(row_key) or "—") for r in records})
    cols = sorted({str(r.get(col_key) or "—") for r in records})
    matrix: dict[str, int] = defaultdict(int)
    for record in records:
        key = f"{record.get(row_key) or '—'}|||{record.get(col_key) or '—'}"
        matrix[key] += 1
    values = [[matrix.get(f"{row}|||{col}", 0) for col in cols] for row in rows]
    return {"rows": rows, "cols": cols, "values": values}


def date_bounds(records: list[dict[str, Any]], fields: list[str]) -> dict[str, str | None]:
    dates: list[str] = []
    for record in records:
        for field in fields:
            val = record.get(field)
            if val:
                dates.append(str(val)[:10])
    if not dates:
        return {"min": None, "max": None}
    dates.sort()
    return {"min": dates[0], "max": dates[-1]}


def stp_filter_options(records: list[dict[str, Any]]) -> dict[str, list[str]]:
    options: dict[str, list[str]] = {
        "state": ["closed", "open"],
        "statusGroup": ["closed", "in_progress", "waiting"],
    }
    for key in STP_MULTI_FILTER_KEYS:
        if key in options:
            continue
        values = sorted({str(r[key]) for r in records if r.get(key)})
        options[key] = values
    return options


def stp_kpi(records: list[dict[str, Any]]) -> dict[str, Any]:
    closed = [r for r in records if r.get("state") == "closed"]
    open_records = [r for r in records if r.get("state") == "open"]
    with_sla = [r for r in closed if r.get("slaMet") is not None]
    sla_ok = [r for r in with_sla if r.get("slaMet") is True]
    confirmed = [r for r in records if r.get("userConfirmed") == "да"]
    overdue_open = [r for r in open_records if _is_overdue(r)]
    hours = [r["resolutionHours"] for r in closed if r.get("resolutionHours") is not None]
    reactions = [r["reactionHours"] for r in records if r.get("reactionHours") is not None]
    errors = [r for r in records if r.get("type") == "Ошибка"]
    waiting_open = [r for r in records if r.get("statusGroup") == "waiting"]
    oiv_waiting = aggregate_oiv_waiting(records)
    top_waiting = next(
        (
            row for row in oiv_waiting
            if row.get("openWaiting") and row.get("avgWaitingHours") is not None
        ),
        next((row for row in oiv_waiting if row.get("avgWaitingHours") is not None), None),
    )

    return {
        "total": len(records),
        "open": len(open_records),
        "closed": len(closed),
        "slaOk": len(sla_ok),
        "slaKnown": len(with_sla),
        "confirmed": len(confirmed),
        "overdueOpen": len(overdue_open),
        "medianResolution": median(hours) if hours else None,
        "medianReaction": median(reactions) if reactions else None,
        "reactionCount": len(reactions),
        "errors": len(errors),
        "waitingOpen": len(waiting_open),
        "topWaitingOiv": top_waiting["name"] if top_waiting else None,
        "topWaitingOivHours": top_waiting["avgWaitingHours"] if top_waiting else None,
        "topWaitingOivOpen": top_waiting["openWaiting"] if top_waiting else 0,
    }


def query_stp(
    records: list[dict[str, Any]],
    *,
    date_field: str,
    date_from: str | None,
    date_to: str | None,
    multi: dict[str, list[str]],
    trend_group_by: str,
    table_limit: int,
    table_offset: int,
) -> dict[str, Any]:
    normalized = [_normalize_stp_record(r) for r in records]
    filtered = filter_records(
        normalized,
        date_field=date_field,
        date_from=date_from,
        date_to=date_to,
        multi=multi,
    )

    sorted_records = sorted(filtered, key=lambda r: r.get("createdAt") or "", reverse=True)
    page = sorted_records[table_offset:table_offset + table_limit]
    oiv_waiting = aggregate_oiv_waiting(filtered)

    solved = count_by(filtered, "solved")
    confirmed = count_by(filtered, "userConfirmed")
    solved_labels = sorted({row[0] for row in solved + confirmed})

    return {
        "filteredCount": len(filtered),
        "totalCount": len(normalized),
        "kpi": stp_kpi(filtered),
        "charts": {
            "trend": build_trend_buckets(filtered, trend_group_by),
            "type": count_by(filtered, "type"),
            "block": count_by(filtered, "block"),
            "oiv": count_by(filtered, "oiv"),
            "module": count_by(filtered, "module"),
            "problemCategory": count_by(filtered, "problemCategory"),
            "statusGroup": count_by_status_group(filtered),
            "errorSide": count_by(filtered, "errorSide"),
            "dailyDetail": build_daily_detail(filtered),
            "statusByCategory": build_status_by_category(filtered),
            "solved": {
                "labels": solved_labels,
                "solved": {row[0]: row[1] for row in solved},
                "confirmed": {row[0]: row[1] for row in confirmed},
            },
            "oivWaiting": [
                [row["name"], row["avgWaitingHours"]]
                for row in oiv_waiting
                if row.get("avgWaitingHours") is not None
            ],
        },
        "analytics": {
            "category": aggregate_groups(filtered, "problemCategory"),
            "block": aggregate_groups(filtered, "block"),
            "errorside": aggregate_groups(filtered, "errorSide", with_error_side=False),
            "oivWaiting": oiv_waiting,
            "crossMatrix": build_cross_matrix(filtered, "problemCategory", "block"),
        },
        "records": {
            "items": page,
            "total": len(filtered),
            "limit": table_limit,
            "offset": table_offset,
        },
    }


def fourme_filter_options(records: list[dict[str, Any]]) -> dict[str, list[str]]:
    options: dict[str, list[str]] = {}
    for key in FOURME_FILTER_KEYS:
        values = sorted({str(r[key]) for r in records if r.get(key)})
        options[key] = values
    return options


def count_fourme_by(
    records: list[dict[str, Any]],
    key: str,
    label_key: str | None = None,
) -> list[list[Any]]:
    counts: dict[str, int] = defaultdict(int)
    for record in records:
        if label_key:
            label = str(record.get(label_key) or record.get(key) or "—")
        else:
            label = str(record.get(key) or "—")
        counts[label] += 1
    return [[name, count] for name, count in sorted(counts.items(), key=lambda x: -x[1])]


def aggregate_fourme_groups(
    records: list[dict[str, Any]],
    group_key: str,
    label_key: str | None = None,
) -> list[dict[str, Any]]:
    total = len(records) or 1
    groups: dict[str, dict[str, Any]] = {}

    for record in records:
        name = str(record.get(group_key) or (record.get(label_key) if label_key else None) or "—")
        group = groups.setdefault(name, {
            "name": name,
            "ids": [],
            "completed": 0,
            "waiting": 0,
            "inProgress": 0,
            "resolutionHours": [],
            "reopenCount": 0,
            "slaKnown": 0,
            "slaOk": 0,
        })
        group["ids"].append(record.get("id"))
        status = record.get("status")
        if status == "completed":
            group["completed"] += 1
        elif status == "waiting_for_customer":
            group["waiting"] += 1
        else:
            group["inProgress"] += 1
        if record.get("resolutionHours") is not None:
            group["resolutionHours"].append(record["resolutionHours"])
        if (record.get("reopenCount") or 0) > 0:
            group["reopenCount"] += 1
        if record.get("slaMet") is not None:
            group["slaKnown"] += 1
            if record.get("slaMet"):
                group["slaOk"] += 1

    rows = []
    for group in groups.values():
        rows.append({
            "name": group["name"],
            "count": len(group["ids"]),
            "share": len(group["ids"]) / total * 100,
            "avgResolution": _avg(group["resolutionHours"]),
            "completed": group["completed"],
            "waiting": group["waiting"],
            "inProgress": group["inProgress"],
            "reopenCount": group["reopenCount"],
            "slaRate": (group["slaOk"] / group["slaKnown"] * 100) if group["slaKnown"] else None,
            "exampleIds": group["ids"][:8],
        })
    return sorted(rows, key=lambda r: -r["count"])


def fourme_kpi(records: list[dict[str, Any]]) -> dict[str, Any]:
    completed = [r for r in records if r.get("status") == "completed"]
    open_records = [r for r in records if r.get("isOpen")]
    waiting = [r for r in records if r.get("isWaiting")]
    with_sla = [r for r in completed if r.get("slaMet") is not None]
    sla_ok = [r for r in with_sla if r.get("slaMet") is True]
    hours = [r["resolutionHours"] for r in completed if r.get("resolutionHours") is not None]
    reopened = [r for r in records if (r.get("reopenCount") or 0) > 0]

    return {
        "total": len(records),
        "open": len(open_records),
        "completed": len(completed),
        "waiting": len(waiting),
        "slaOk": len(sla_ok),
        "slaKnown": len(with_sla),
        "medianResolution": median(hours) if hours else None,
        "reopened": len(reopened),
        "reviewed": sum(1 for r in records if r.get("reviewed")),
    }


def query_fourme(
    records: list[dict[str, Any]],
    *,
    date_field: str,
    date_from: str | None,
    date_to: str | None,
    multi: dict[str, list[str]],
    trend_group_by: str,
    table_limit: int,
    table_offset: int,
) -> dict[str, Any]:
    filtered = filter_records(
        records,
        date_field=date_field,
        date_from=date_from,
        date_to=date_to,
        multi=multi,
    )
    sorted_records = sorted(filtered, key=lambda r: r.get("createdAt") or "", reverse=True)
    page = sorted_records[table_offset:table_offset + table_limit]
    closed = [r for r in filtered if r.get("status") == "completed"]
    with_impact = [r for r in filtered if r.get("impactLabel")]

    return {
        "filteredCount": len(filtered),
        "totalCount": len(records),
        "kpi": fourme_kpi(filtered),
        "charts": {
            "trend": build_trend_buckets(filtered, trend_group_by),
            "status": count_fourme_by(filtered, "statusLabel"),
            "category": count_fourme_by(filtered, "categoryLabel"),
            "service": count_fourme_by(filtered, "serviceShort"),
            "member": count_fourme_by(filtered, "memberShort"),
            "source": count_fourme_by(filtered, "source"),
            "completion": count_fourme_by(closed, "completionReasonLabel"),
            "impact": count_fourme_by(with_impact, "impactLabel"),
            "agile": count_fourme_by(filtered, "agileColumn"),
        },
        "analytics": {
            "service": aggregate_fourme_groups(filtered, "serviceShort"),
            "member": aggregate_fourme_groups(filtered, "memberShort"),
            "organization": aggregate_fourme_groups(filtered, "organization"),
            "source": aggregate_fourme_groups(filtered, "source"),
            "crossMatrix": build_cross_matrix(filtered, "categoryLabel", "serviceShort"),
        },
        "records": {
            "items": page,
            "total": len(filtered),
            "limit": table_limit,
            "offset": table_offset,
        },
    }
