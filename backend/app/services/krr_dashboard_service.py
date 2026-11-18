"""Сводка дашборда «Версии работ КРР МР» по суточному снимку."""

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from fastapi import HTTPException, status

from app.db import get_db
from app.services.analytics_processor import analytics_now
from app.services.analytics_queries import AnalyticsFilterSpec

EMPTY = "__empty__"
EMPTY_LABEL = "Не указано"
OPTION_LIMIT = 60
TOP_PIE = 8
TOP_BAR = 12
DEFAULT_DATE = "created_date_version"


@dataclass(frozen=True)
class _Column:
    key: str
    label: str
    kind: str


COLUMNS: tuple[_Column, ...] = (
    _Column("name_work_version", "Название версии", "text"),
    _Column("name", "Наименование", "text"),
    _Column("type_object", "Тип объекта", "text"),
    _Column("category_object_name", "Категория объекта", "text"),
    _Column("subcategory_object_name", "Подкатегория объекта", "text"),
    _Column("adm_district", "Округ", "text"),
    _Column("district", "Район", "text"),
    _Column("address", "Адрес", "text"),
    _Column("work_date", "Год работ (текст)", "text"),
    _Column("stage", "Стадия", "text"),
    _Column("link", "Ссылка", "text"),
    _Column("dk", "ДК", "bool"),
    _Column("category_object", "Категория", "text"),
    _Column("fact_start_date", "Фактическое начало", "date"),
    _Column("fact_end_date", "Фактическое окончание", "date"),
    _Column("plan_start_date", "Плановое начало", "date"),
    _Column("plan_end_date", "Плановое окончание", "date"),
    _Column("square", "Площадь", "number"),
    _Column("work_year", "Год работ", "number"),
    _Column("load_status", "Статус загрузки", "text"),
    _Column("pir_date_plan_beg", "ПИР, план начала", "date"),
    _Column("smr_date_plan_beg", "СМР, план начала", "date"),
    _Column("pir_date_plan_end", "ПИР, план окончания", "date"),
    _Column("smr_date_plan_end", "СМР, план окончания", "date"),
    _Column("pir_date_fact_beg", "ПИР, факт начала", "date"),
    _Column("pir_date_fact_end", "ПИР, факт окончания", "date"),
    _Column("smr_date_fact_beg", "СМР, факт начала", "date"),
    _Column("smr_date_fact_end", "СМР, факт окончания", "date"),
    _Column("category_event", "Категория мероприятия", "text"),
    _Column("customer_pir", "Заказчик ПИР", "text"),
    _Column("customer_smr", "Заказчик СМР", "text"),
    _Column("activation_status", "Статус акта", "text"),
    _Column("program", "Программа", "text"),
    _Column("address_bti", "Адрес БТИ", "text"),
    _Column("version", "Версия", "text"),
    _Column("date_archive", "Дата архива", "date"),
    _Column("date_change", "Дата изменения", "date"),
    _Column("date_creation", "Дата создания", "date"),
    _Column("inn_contractor", "ИНН подрядчика", "text"),
    _Column("contractor", "Подрядчик", "text"),
    _Column("footing", "Основание", "text"),
    _Column("reason_cansel", "Причина отмены", "text"),
    _Column("nature_of_the_work_smr", "Характер работ СМР", "text"),
    _Column("type_sys", "Тип системы", "text"),
    _Column("finance", "Финансирование", "text"),
    _Column("departmental_oiv_class_name", "Класс ведомственного ОИВ", "text"),
    _Column("status_id_name", "Статус", "text"),
    _Column("customer", "Заказчик", "text"),
    _Column("balance_holder", "Балансодержатель", "text"),
    _Column("departmental_oiv", "Ведомственный ОИВ", "text"),
    _Column("geometry_valid", "Геометрия корректна", "bool"),
    _Column("cpgz_names", "Виды работ", "text"),
    _Column("created_date_work", "Дата создания работы", "date"),
    _Column("changed_data_work", "Дата изменения работы", "date"),
    _Column("created_date_version", "Дата создания версии", "date"),
    _Column("changed_date_version", "Дата изменения версии", "date"),
)

_BY_KEY = {column.key: column for column in COLUMNS}
_DATE_KEYS = {column.key for column in COLUMNS if column.kind == "date"}
_RECORD_COLUMNS = (
    "name_work_version",
    "work_year",
    "stage",
    "adm_district",
    "district",
    "departmental_oiv",
    "balance_holder",
    "dk",
    "program",
    "status_id_name",
    "changed_date_version",
    "link",
)


class KrrDashboardService:
    def query(self, spec: AnalyticsFilterSpec, *, table_limit: int) -> dict:
        today = self._succeeded_day(offset_days=0)
        if today is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Снимок за сегодня ещё не загружен. Запустите синхронизацию КРР.",
            )
        snapshot_date, fetched_at, total_count = today
        yesterday = self._succeeded_day(offset_days=1)
        date_column = spec.date_column if spec.date_column in _DATE_KEYS else DEFAULT_DATE
        where, params = _conditions(spec, date_column)
        with get_db(read_timeout=60) as conn:
            with conn.cursor() as cursor:
                kpi = _kpi(cursor, snapshot_date, where, params, yesterday)
                charts = {
                    "created": _timelines(cursor, snapshot_date, where, params, "created_date_version"),
                    "changed": _timelines(cursor, snapshot_date, where, params, "changed_date_version"),
                    "oiv_class": _distribution(cursor, snapshot_date, where, params, "departmental_oiv_class_name", TOP_PIE),
                    "stage": _distribution(cursor, snapshot_date, where, params, "stage", TOP_PIE),
                    "district": _distribution(cursor, snapshot_date, where, params, "adm_district", TOP_BAR),
                    "program": _distribution(cursor, snapshot_date, where, params, "program", TOP_BAR),
                    "status": _distribution(cursor, snapshot_date, where, params, "status_id_name", TOP_BAR),
                    "year": _distribution(cursor, snapshot_date, where, params, "work_year", 20),
                    "activation": _distribution(cursor, snapshot_date, where, params, "activation_status", TOP_PIE),
                }
                columns = [
                    _column_meta(cursor, snapshot_date, where, params, column)
                    for column in COLUMNS
                ]
                bounds = _date_bounds(cursor, snapshot_date)
                records = _records(cursor, snapshot_date, where, params, table_limit, kpi["versions"])
        return {
            "snapshot_date": snapshot_date,
            "fetched_at": fetched_at or analytics_now(),
            "title": "Версии работ КРР МР",
            "total_count": total_count,
            "filtered_count": kpi["versions"],
            "date_column": date_column,
            "columns": columns,
            "date_bounds": bounds,
            "kpi": kpi,
            "charts": charts,
            "records": records,
        }

    def _succeeded_day(self, *, offset_days: int) -> tuple[date, datetime | None, int] | None:
        day = analytics_now().date()
        if offset_days:
            day = day.fromordinal(day.toordinal() - offset_days)
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT snapshot_date, finished_at, stored_count
                    FROM krr_daily_snapshots
                    WHERE snapshot_date = %s AND status = 'succeeded'
                    """,
                    (day,),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        snapshot_date = row["snapshot_date"]
        if isinstance(snapshot_date, datetime):
            snapshot_date = snapshot_date.date()
        return snapshot_date, row["finished_at"], int(row["stored_count"] or 0)


def _conditions(spec: AnalyticsFilterSpec, date_column: str) -> tuple[str, list]:
    clauses: list[str] = []
    params: list = []
    if spec.period_start is not None:
        clauses.append(f"`{date_column}` >= %s")
        params.append(spec.period_start)
    if spec.period_end is not None:
        clauses.append(f"`{date_column}` <= %s")
        params.append(spec.period_end)
    for key, values in spec.selected.items():
        column = _BY_KEY.get(key)
        if column is None or not values or column.kind == "date":
            continue
        parts, part_params = _selected_clause(column, values[:100])
        if parts:
            clauses.append(parts)
            params.extend(part_params)
    for key, query in spec.queries.items():
        column = _BY_KEY.get(key)
        text = (query or "").strip()
        if column is None or column.kind == "date" or not text:
            continue
        clauses.append(f"CAST(`{key}` AS CHAR) LIKE %s ESCAPE '\\\\'")
        params.append(_like(text[:200]))
    return (" AND ".join(clauses), params)


def _selected_clause(column: _Column, values: list[str]) -> tuple[str, list]:
    include_empty = EMPTY in values
    concrete = [value for value in values if value != EMPTY]
    parts: list[str] = []
    params: list = []
    if concrete and column.kind == "bool":
        flags = []
        if any(value in {"1", "true", "да"} for value in concrete):
            flags.append(1)
        if any(value in {"0", "false", "нет"} for value in concrete):
            flags.append(0)
        if flags:
            parts.append(f"`{column.key}` IN ({', '.join(['%s'] * len(flags))})")
            params.extend(flags)
    elif concrete:
        parts.append(
            f"CAST(`{column.key}` AS CHAR) IN ({', '.join(['%s'] * len(concrete))})"
        )
        params.extend(concrete)
    if include_empty:
        if column.kind in {"text", "number"}:
            parts.append(f"(`{column.key}` IS NULL OR CAST(`{column.key}` AS CHAR) = '')")
        else:
            parts.append(f"`{column.key}` IS NULL")
    if not parts:
        return "", []
    return "(" + " OR ".join(parts) + ")", params


def _kpi(cursor, snapshot_date: date, where: str, params: list, yesterday) -> dict:
    filled = " + ".join(_filled_expr(column) for column in COLUMNS)
    sql = f"""
        SELECT
          COUNT(*) AS versions,
          COUNT(DISTINCT id_work) AS unique_works,
          COUNT(DISTINCT NULLIF(TRIM(departmental_oiv), '')) AS oiv_count,
          COUNT(DISTINCT NULLIF(TRIM(balance_holder), '')) AS balance_holders,
          SUM(dk = 1) AS dk_count,
          MAX(changed_date_version) AS last_changed,
          COALESCE(SUM({filled}), 0) AS filled_cells
        FROM krr_work_versions
        WHERE snapshot_date = %s {('AND ' + where) if where else ''}
    """
    cursor.execute(sql, [snapshot_date, *params])
    row = cursor.fetchone()
    versions = int(row["versions"] or 0)
    cells = versions * len(COLUMNS)
    fill = round((float(row["filled_cells"] or 0) / cells) * 100, 1) if cells else 0.0
    delta = None
    if yesterday is not None:
        cursor.execute(
            f"""
            SELECT COUNT(*) AS versions
            FROM krr_work_versions
            WHERE snapshot_date = %s {('AND ' + where) if where else ''}
            """,
            [yesterday[0], *params],
        )
        previous = int(cursor.fetchone()["versions"] or 0)
        delta = versions - previous
    last_changed = row["last_changed"]
    if isinstance(last_changed, datetime):
        last_changed = last_changed.date()
    return {
        "versions": versions,
        "unique_works": int(row["unique_works"] or 0),
        "oiv_count": int(row["oiv_count"] or 0),
        "balance_holders": int(row["balance_holders"] or 0),
        "delta": delta,
        "dk_count": int(row["dk_count"] or 0),
        "last_changed": last_changed,
        "fill_percent": fill,
    }


def _filled_expr(column: _Column) -> str:
    if column.kind in {"text", "number"}:
        return f"(`{column.key}` IS NOT NULL AND CAST(`{column.key}` AS CHAR) <> '')"
    return f"(`{column.key}` IS NOT NULL)"


def _timelines(cursor, snapshot_date: date, where: str, params: list, column: str) -> dict:
    extra = f"AND {where}" if where else ""
    cursor.execute(
        f"""
        SELECT `{column}` AS day, COUNT(*) AS value
        FROM krr_work_versions
        WHERE snapshot_date = %s AND `{column}` IS NOT NULL {extra}
        GROUP BY `{column}`
        ORDER BY `{column}`
        """,
        [snapshot_date, *params],
    )
    daily: list[tuple[date, int]] = []
    for row in cursor.fetchall():
        day = row["day"]
        if isinstance(day, datetime):
            day = day.date()
        if isinstance(day, date):
            daily.append((day, int(row["value"] or 0)))
    return {
        "day": _series(daily, "day"),
        "week": _series(daily, "week"),
        "month": _series(daily, "month"),
    }


def _series(daily: list[tuple[date, int]], group: str) -> list[dict]:
    if not daily:
        return []
    grouped: dict[date, int] = {}
    for day, value in daily:
        if group == "week":
            key = day - timedelta(days=day.weekday())
        elif group == "month":
            key = day.replace(day=1)
        else:
            key = day
        grouped[key] = grouped.get(key, 0) + value
    keys = sorted(grouped)
    if group == "day" and (keys[-1] - keys[0]).days <= 120:
        filled: list[date] = []
        cursor = keys[0]
        while cursor <= keys[-1]:
            filled.append(cursor)
            cursor += timedelta(days=1)
        keys = filled
    return [
        {"label": _trend_label(day, group), "value": grouped.get(day, 0)}
        for day in keys
    ]


def _trend_label(day: date, group: str) -> str:
    if group == "month":
        return f"{day.month:02d}.{day.year}"
    return f"{day.day:02d}.{day.month:02d}.{day.year % 100:02d}"


def _distribution(
    cursor,
    snapshot_date: date,
    where: str,
    params: list,
    column: str,
    limit: int,
) -> list[dict]:
    extra = f"AND {where}" if where else ""
    cursor.execute(
        f"""
        SELECT
          COALESCE(NULLIF(TRIM(CAST(`{column}` AS CHAR)), ''), %s) AS label,
          COUNT(*) AS value
        FROM krr_work_versions
        WHERE snapshot_date = %s {extra}
        GROUP BY label
        ORDER BY value DESC, label
        """,
        [EMPTY_LABEL, snapshot_date, *params],
    )
    rows = [{"label": row["label"], "value": int(row["value"])} for row in cursor.fetchall()]
    if len(rows) <= limit:
        return rows
    head = rows[: limit - 1]
    rest = sum(row["value"] for row in rows[limit - 1 :])
    if rest:
        head.append({"label": "Другие", "value": rest})
    return head


def _column_meta(cursor, snapshot_date: date, where: str, params: list, column: _Column) -> dict:
    payload = {
        "key": column.key,
        "label": column.label,
        "kind": "date" if column.kind == "date" else "text",
        "computed": False,
        "options": [],
    }
    if column.kind == "date":
        return payload
    extra = f"AND {where}" if where else ""
    if column.kind == "bool":
        cursor.execute(
            f"""
            SELECT
              CASE WHEN `{column.key}` IS NULL THEN %s WHEN `{column.key}` = 1 THEN '1' ELSE '0' END AS value_key,
              COUNT(*) AS value
            FROM krr_work_versions
            WHERE snapshot_date = %s {extra}
            GROUP BY value_key
            ORDER BY value DESC
            """,
            [EMPTY, snapshot_date, *params],
        )
        payload["options"] = [
            {"key": row["value_key"], "label": _bool_label(row["value_key"]), "value": int(row["value"])}
            for row in cursor.fetchall()
        ]
        return payload
    cursor.execute(
        f"""
        SELECT
          CASE
            WHEN `{column.key}` IS NULL OR CAST(`{column.key}` AS CHAR) = '' THEN %s
            ELSE LEFT(CAST(`{column.key}` AS CHAR), 180)
          END AS value_key,
          COUNT(*) AS value
        FROM krr_work_versions
        WHERE snapshot_date = %s {extra}
        GROUP BY value_key
        ORDER BY value DESC
        LIMIT %s
        """,
        [EMPTY, snapshot_date, *params, OPTION_LIMIT + 1],
    )
    rows = cursor.fetchall()
    if len(rows) > OPTION_LIMIT:
        return payload
    payload["options"] = [
        {
            "key": row["value_key"],
            "label": EMPTY_LABEL if row["value_key"] == EMPTY else row["value_key"],
            "value": int(row["value"]),
        }
        for row in rows
    ]
    return payload


def _date_bounds(cursor, snapshot_date: date) -> dict:
    selects = ", ".join(
        f"MIN(`{key}`) AS min_{index}, MAX(`{key}`) AS max_{index}"
        for index, key in enumerate(_DATE_KEYS)
    )
    cursor.execute(
        f"SELECT {selects} FROM krr_work_versions WHERE snapshot_date = %s",
        (snapshot_date,),
    )
    row = cursor.fetchone() or {}
    bounds = {}
    for index, key in enumerate(_DATE_KEYS):
        start = row.get(f"min_{index}")
        end = row.get(f"max_{index}")
        if isinstance(start, datetime):
            start = start.date()
        if isinstance(end, datetime):
            end = end.date()
        if isinstance(start, date) and isinstance(end, date):
            bounds[key] = {"min": start, "max": end}
    return bounds


def _records(cursor, snapshot_date: date, where: str, params: list, limit: int, total: int) -> dict:
    names = ", ".join(f"`{key}`" for key in _RECORD_COLUMNS)
    extra = f"AND {where}" if where else ""
    cursor.execute(
        f"""
        SELECT {names}
        FROM krr_work_versions
        WHERE snapshot_date = %s {extra}
        ORDER BY changed_date_version DESC, id_unique DESC
        LIMIT %s
        """,
        [snapshot_date, *params, limit],
    )
    items = []
    for row in cursor.fetchall():
        item = dict(row)
        if item.get("dk") is not None:
            item["dk"] = bool(item["dk"])
        changed = item.get("changed_date_version")
        if isinstance(changed, datetime):
            item["changed_date_version"] = changed.date()
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": 0}


def _bool_label(value: str) -> str:
    if value == "1":
        return "Да"
    if value == "0":
        return "Нет"
    return EMPTY_LABEL


def _like(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


krr_dashboard_service = KrrDashboardService()
