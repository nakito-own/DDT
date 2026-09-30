"""Фильтрация заявок СТП и агрегаты дашборда «Аналитика»."""

from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from statistics import median

from app.services.analytics_processor import (
    COL_CREATED,
    STATE_LABELS,
    STATUS_GROUP_LABELS,
    analytics_now,
    hours_between,
)

STATUS_GROUP_ORDER = ("in_progress", "waiting", "closed")
TREND_GROUPINGS = ("day", "week", "month")
TOP_CHART_LIMIT = 10
STATUS_BY_CATEGORY_LIMIT = 8
EXAMPLE_IDS_LIMIT = 8
EMPTY_LABEL = "—"


@dataclass(frozen=True)
class AnalyticsFilterSpec:
    date_column: str | None = None
    period_start: date | None = None
    period_end: date | None = None
    selected: dict[str, list[str]] = field(default_factory=dict)
    queries: dict[str, str] = field(default_factory=dict)


def _avg(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def _parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def resolve_date_column(columns: list[dict], requested: str | None) -> str:
    date_keys = [column["key"] for column in columns if column["kind"] == "date"]
    if requested and requested in date_keys:
        return requested
    if COL_CREATED in date_keys:
        return COL_CREATED
    return date_keys[0] if date_keys else ""


def filter_tickets(
    tickets: list[dict],
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
    for ticket in tickets:
        fields = ticket["fields"]
        if any(fields.get(key, "") not in values for key, values in selected.items()):
            continue
        if any(query not in fields.get(key, "").lower() for key, query in queries.items()):
            continue
        if start or end:
            day = ticket["dates"].get(date_column)
            if not day or (start and day < start) or (end and day > end):
                continue
        result.append(ticket)
    return result


def date_bounds(tickets: list[dict], columns: list[dict]) -> dict[str, dict]:
    bounds = {}
    for column in columns:
        if column["kind"] != "date":
            continue
        days = [ticket["dates"][column["key"]] for ticket in tickets if column["key"] in ticket["dates"]]
        if days:
            bounds[column["key"]] = {"min": min(days), "max": max(days)}
    return bounds


def is_overdue(ticket: dict, now: datetime) -> bool:
    if ticket["state"] != "open":
        return False
    target = _parse_iso(ticket.get("sla_target"))
    return target is not None and now > target


def waiting_hours(ticket: dict, now: datetime) -> float | None:
    if ticket["status_group"] == "waiting" and ticket.get("waiting_started_at"):
        return hours_between(_parse_iso(ticket["waiting_started_at"]), now)
    return ticket.get("client_response_hours")


def count_by(tickets: list[dict], key: str, *, limit: int | None = None) -> list[dict]:
    counts = Counter(str(ticket.get(key) or EMPTY_LABEL) for ticket in tickets)
    ordered = sorted(counts.items(), key=lambda item: -item[1])
    if limit is not None:
        ordered = ordered[:limit]
    return [{"label": label, "value": value} for label, value in ordered]


def count_by_status_group(tickets: list[dict]) -> list[dict]:
    counts = Counter(ticket["status_group"] for ticket in tickets)
    points = [
        {"label": STATUS_GROUP_LABELS[key], "value": counts[key]}
        for key in STATUS_GROUP_ORDER
        if counts.get(key)
    ]
    extra = sorted(
        ((key, value) for key, value in counts.items() if key not in STATUS_GROUP_ORDER),
        key=lambda item: -item[1],
    )
    points.extend(
        {"label": STATUS_GROUP_LABELS.get(key, key), "value": value}
        for key, value in extra
    )
    return points


def _week_start(day: date) -> date:
    return day - timedelta(days=day.weekday())


def _period_key(value: str | None, group_by: str) -> str | None:
    if not value:
        return None
    day = value[:10]
    if group_by == "day":
        return day
    if group_by == "month":
        return day[:7]
    return _week_start(date.fromisoformat(day)).isoformat()


def _format_period_label(key: str, group_by: str) -> str:
    if group_by == "month":
        year, month = key.split("-")
        return f"{month}.{year}"
    if group_by == "day":
        year, month, day = key.split("-")
        return f"{day}.{month}.{year[2:]}"
    start = date.fromisoformat(key)
    end = start + timedelta(days=6)
    return f"{start.strftime('%d.%m')}–{end.strftime('%d.%m')}"


def _enumerate_periods(min_key: str, max_key: str, group_by: str) -> list[str]:
    if group_by == "month":
        year, month = map(int, min_key.split("-"))
        end_year, end_month = map(int, max_key.split("-"))
        result = []
        while (year, month) <= (end_year, end_month):
            result.append(f"{year}-{month:02d}")
            month += 1
            if month > 12:
                month = 1
                year += 1
        return result

    step = timedelta(days=7 if group_by == "week" else 1)
    cursor = date.fromisoformat(min_key)
    end = date.fromisoformat(max_key)
    result = []
    while cursor <= end:
        result.append(cursor.isoformat())
        cursor += step
    return result


def build_trend(tickets: list[dict], group_by: str) -> dict:
    buckets: dict[str, dict[str, int]] = defaultdict(lambda: {"created": 0, "closed": 0})
    for ticket in tickets:
        created_key = _period_key(ticket.get("created_at"), group_by)
        if created_key:
            buckets[created_key]["created"] += 1
        closed_key = _period_key(ticket.get("completed_at"), group_by)
        if closed_key:
            buckets[closed_key]["closed"] += 1

    if not buckets:
        return {"labels": [], "created": [], "closed": []}
    keys = _enumerate_periods(min(buckets), max(buckets), group_by)
    return {
        "labels": [_format_period_label(key, group_by) for key in keys],
        "created": [buckets[key]["created"] if key in buckets else 0 for key in keys],
        "closed": [buckets[key]["closed"] if key in buckets else 0 for key in keys],
    }


def build_daily_detail(tickets: list[dict]) -> list[dict]:
    days: dict[str, dict] = {}

    def bucket(day: str) -> dict:
        return days.setdefault(day, {"day": day, "created": 0, "closed": 0, "reactions": []})

    for ticket in tickets:
        created = ticket.get("created_at")
        if created:
            bucket(created[:10])["created"] += 1
            if ticket.get("reaction_hours") is not None:
                bucket(created[:10])["reactions"].append(ticket["reaction_hours"])
        closed = ticket.get("completed_at")
        if closed:
            bucket(closed[:10])["closed"] += 1

    result = []
    for day in sorted(days):
        item = days[day]
        reaction = _avg(item["reactions"])
        result.append(
            {
                "day": day,
                "created": item["created"],
                "closed": item["closed"],
                "avg_reaction_hours": round(reaction, 1) if reaction is not None else None,
            }
        )
    return result


def build_status_by_category(tickets: list[dict]) -> dict:
    top = count_by(tickets, "problem_category", limit=STATUS_BY_CATEGORY_LIMIT)
    categories = [point["label"] for point in top]
    counts: dict[str, Counter] = {category: Counter() for category in categories}
    for ticket in tickets:
        category = ticket.get("problem_category") or EMPTY_LABEL
        if category in counts:
            counts[category][ticket["status_group"]] += 1
    return {
        "categories": categories,
        "closed": [counts[category]["closed"] for category in categories],
        "in_progress": [counts[category]["in_progress"] for category in categories],
        "waiting": [counts[category]["waiting"] for category in categories],
    }


def build_solved(tickets: list[dict]) -> dict:
    solved = Counter(str(ticket.get("solved") or EMPTY_LABEL) for ticket in tickets)
    confirmed = Counter(str(ticket.get("user_confirmed") or EMPTY_LABEL) for ticket in tickets)
    labels = sorted(set(solved) | set(confirmed))
    return {
        "labels": labels,
        "solved": [solved.get(label, 0) for label in labels],
        "confirmed": [confirmed.get(label, 0) for label in labels],
    }


def aggregate_oiv_waiting(tickets: list[dict], now: datetime) -> list[dict]:
    groups: dict[str, dict] = {}
    for ticket in tickets:
        is_waiting = ticket["status_group"] == "waiting"
        if not (ticket.get("has_waiting_episode") or is_waiting):
            continue
        hours = waiting_hours(ticket, now)
        if hours is None and not is_waiting:
            continue

        name = ticket.get("oiv") or EMPTY_LABEL
        group = groups.setdefault(
            name, {"name": name, "ids": [], "hours": [], "open_waiting": 0}
        )
        group["ids"].append(ticket["id"])
        if is_waiting:
            group["open_waiting"] += 1
        if hours is not None:
            group["hours"].append(hours)

    rows = [
        {
            "name": group["name"],
            "episode_count": len(group["ids"]),
            "open_waiting": group["open_waiting"],
            "avg_waiting_hours": _avg(group["hours"]),
            "median_waiting_hours": median(group["hours"]) if group["hours"] else None,
            "max_waiting_hours": max(group["hours"]) if group["hours"] else None,
            "example_ids": group["ids"][:EXAMPLE_IDS_LIMIT],
        }
        for group in groups.values()
    ]
    return sorted(
        rows,
        key=lambda row: (
            -(row["avg_waiting_hours"] or 0),
            -row["open_waiting"],
            -row["episode_count"],
        ),
    )


def aggregate_groups(tickets: list[dict], key: str, *, with_error_side: bool = True) -> list[dict]:
    total = len(tickets) or 1
    groups: dict[str, dict] = {}
    for ticket in tickets:
        name = str(ticket.get(key) or EMPTY_LABEL)
        group = groups.setdefault(
            name,
            {
                "ids": [],
                "status": Counter(),
                "resolution": [],
                "reaction": [],
                "error_sides": Counter(),
            },
        )
        group["ids"].append(ticket["id"])
        group["status"][ticket["status_group"]] += 1
        if ticket.get("resolution_hours") is not None:
            group["resolution"].append(ticket["resolution_hours"])
        if ticket.get("reaction_hours") is not None:
            group["reaction"].append(ticket["reaction_hours"])
        if with_error_side:
            group["error_sides"][ticket.get("error_side") or EMPTY_LABEL] += 1

    rows = []
    for name, group in groups.items():
        count = len(group["ids"])
        rows.append(
            {
                "name": name,
                "count": count,
                "share": count / total * 100,
                "avg_resolution_hours": _avg(group["resolution"]),
                "avg_reaction_hours": _avg(group["reaction"]),
                "closed": group["status"]["closed"],
                "in_progress": count - group["status"]["closed"] - group["status"]["waiting"],
                "waiting": group["status"]["waiting"],
                "error_side": (
                    group["error_sides"].most_common(1)[0][0]
                    if with_error_side and group["error_sides"]
                    else None
                ),
                "example_ids": group["ids"][:EXAMPLE_IDS_LIMIT],
            }
        )
    return sorted(rows, key=lambda row: -row["count"])


def build_cross_matrix(tickets: list[dict], row_key: str, col_key: str) -> dict:
    cells = Counter(
        (str(ticket.get(row_key) or EMPTY_LABEL), str(ticket.get(col_key) or EMPTY_LABEL))
        for ticket in tickets
    )
    rows = sorted({row for row, _ in cells})
    cols = sorted({col for _, col in cells})
    return {
        "rows": rows,
        "cols": cols,
        "values": [[cells.get((row, col), 0) for col in cols] for row in rows],
    }


def build_kpi(tickets: list[dict], oiv_waiting: list[dict], now: datetime) -> dict:
    closed = [ticket for ticket in tickets if ticket["state"] == "closed"]
    open_tickets = [ticket for ticket in tickets if ticket["state"] == "open"]
    with_sla = [ticket for ticket in closed if ticket.get("sla_met") is not None]
    resolution = [
        ticket["resolution_hours"] for ticket in closed if ticket.get("resolution_hours") is not None
    ]
    reactions = [
        ticket["reaction_hours"] for ticket in tickets if ticket.get("reaction_hours") is not None
    ]
    top_waiting = next(
        (row for row in oiv_waiting if row["open_waiting"] and row["avg_waiting_hours"] is not None),
        next((row for row in oiv_waiting if row["avg_waiting_hours"] is not None), None),
    )
    return {
        "total": len(tickets),
        "open": len(open_tickets),
        "closed": len(closed),
        "sla_ok": sum(1 for ticket in with_sla if ticket["sla_met"]),
        "sla_known": len(with_sla),
        "confirmed": sum(
            1 for ticket in tickets if (ticket.get("user_confirmed") or "").lower() == "да"
        ),
        "overdue_open": sum(1 for ticket in open_tickets if is_overdue(ticket, now)),
        "median_resolution_hours": median(resolution) if resolution else None,
        "median_reaction_hours": median(reactions) if reactions else None,
        "reaction_count": len(reactions),
        "errors": sum(1 for ticket in tickets if ticket.get("type") == "Ошибка"),
        "waiting_open": sum(1 for ticket in tickets if ticket["status_group"] == "waiting"),
        "top_waiting_oiv": top_waiting["name"] if top_waiting else None,
        "top_waiting_oiv_hours": top_waiting["avg_waiting_hours"] if top_waiting else None,
        "top_waiting_oiv_open": top_waiting["open_waiting"] if top_waiting else 0,
    }


def _table_row(ticket: dict, now: datetime) -> dict:
    return {
        "id": ticket["id"],
        "permalink": ticket.get("permalink"),
        "state": ticket["state"],
        "state_label": STATE_LABELS[ticket["state"]],
        "type": ticket.get("type"),
        "block": ticket.get("block"),
        "problem_category": ticket.get("problem_category"),
        "subject": ticket.get("subject"),
        "member": ticket.get("member"),
        "requested_by": ticket.get("requested_by"),
        "oiv": ticket.get("oiv"),
        "created_at": ticket.get("created_at"),
        "completed_at": ticket.get("completed_at"),
        "resolution_hours": ticket.get("resolution_hours"),
        "reaction_hours": ticket.get("reaction_hours"),
        "error_side": ticket.get("error_side"),
        "sla_met": ticket.get("sla_met"),
        "is_overdue": is_overdue(ticket, now),
    }


def query_dashboard(
    dataset: dict,
    spec: AnalyticsFilterSpec,
    *,
    table_limit: int,
    table_offset: int,
) -> dict:
    now = analytics_now()
    tickets: list[dict] = dataset["tickets"]
    columns: list[dict] = dataset["columns"]
    date_column = resolve_date_column(columns, spec.date_column)
    filtered = filter_tickets(tickets, spec, date_column)
    oiv_waiting = aggregate_oiv_waiting(filtered, now)
    ordered = sorted(filtered, key=lambda ticket: ticket.get("created_at") or "", reverse=True)

    return {
        "total_count": len(tickets),
        "filtered_count": len(filtered),
        "date_column": date_column,
        "columns": columns,
        "date_bounds": date_bounds(tickets, columns),
        "kpi": build_kpi(filtered, oiv_waiting, now),
        "charts": {
            "trend": {group_by: build_trend(filtered, group_by) for group_by in TREND_GROUPINGS},
            "type": count_by(filtered, "type"),
            "block": count_by(filtered, "block", limit=TOP_CHART_LIMIT),
            "oiv": count_by(filtered, "oiv", limit=TOP_CHART_LIMIT),
            "module": count_by(filtered, "module", limit=TOP_CHART_LIMIT),
            "problem_category": count_by(filtered, "problem_category", limit=TOP_CHART_LIMIT),
            "status_group": count_by_status_group(filtered),
            "error_side": count_by(filtered, "error_side"),
            "oiv_waiting": [
                {"label": row["name"], "hours": row["avg_waiting_hours"]}
                for row in oiv_waiting
                if row["avg_waiting_hours"] is not None
            ],
            "daily_detail": build_daily_detail(filtered),
            "status_by_category": build_status_by_category(filtered),
            "solved": build_solved(filtered),
        },
        "summary": {
            "category": aggregate_groups(filtered, "problem_category"),
            "block": aggregate_groups(filtered, "block"),
            "error_side": aggregate_groups(filtered, "error_side", with_error_side=False),
            "oiv_waiting": oiv_waiting,
            "cross_matrix": build_cross_matrix(filtered, "problem_category", "block"),
        },
        "records": {
            "items": [
                _table_row(ticket, now)
                for ticket in ordered[table_offset : table_offset + table_limit]
            ],
            "total": len(filtered),
            "limit": table_limit,
            "offset": table_offset,
        },
    }
