"""Агрегаты аналитики работ и качества данных КРР по текущему снимку версий."""

from datetime import date

from fastapi import HTTPException, status

EMPTY_LABEL = "Не указано"
LIST_CAP = 80
QUALITY_WEIGHTS = {
    "completeness": 0.30,
    "correctness": 0.25,
    "consistency": 0.25,
    "freshness": 0.10,
    "uniqueness": 0.10,
}

_DONE = (
    "(LOWER(COALESCE(v.stage, '')) LIKE '%заверш%' "
    "OR LOWER(COALESCE(v.status_id_name, '')) LIKE '%заверш%')"
)
_CANCEL = (
    "(LOWER(COALESCE(v.stage, '')) LIKE '%отмен%' "
    "OR LOWER(COALESCE(v.status_id_name, '')) LIKE '%отмен%' "
    "OR LOWER(COALESCE(v.stage, '')) LIKE '%аннул%' "
    "OR LOWER(COALESCE(v.status_id_name, '')) LIKE '%аннул%')"
)
_DONE_ONLY = f"({_DONE} AND NOT {_CANCEL})"
_IN_WORK = (
    f"(NOT {_DONE} AND NOT {_CANCEL} AND ("
    "LOWER(COALESCE(v.stage, '')) LIKE '%в работе%' "
    "OR LOWER(COALESCE(v.stage, '')) LIKE '%реализ%' "
    "OR LOWER(COALESCE(v.stage, '')) LIKE '%исполн%' "
    "OR LOWER(COALESCE(v.stage, '')) LIKE '%процесс%' "
    "OR LOWER(COALESCE(v.status_id_name, '')) LIKE '%в работе%' "
    "OR LOWER(COALESCE(v.status_id_name, '')) LIKE '%реализ%'"
    "))"
)
_SMR = (
    "((v.customer_smr IS NOT NULL AND TRIM(v.customer_smr) <> '') "
    "OR v.smr_date_plan_beg IS NOT NULL OR v.smr_date_plan_end IS NOT NULL "
    "OR v.smr_date_fact_beg IS NOT NULL OR v.smr_date_fact_end IS NOT NULL "
    "OR (v.nature_of_the_work_smr IS NOT NULL AND TRIM(v.nature_of_the_work_smr) <> ''))"
)
_PIR = (
    "((v.customer_pir IS NOT NULL AND TRIM(v.customer_pir) <> '') "
    "OR v.pir_date_plan_beg IS NOT NULL OR v.pir_date_plan_end IS NOT NULL "
    "OR v.pir_date_fact_beg IS NOT NULL OR v.pir_date_fact_end IS NOT NULL)"
)
_BOTH_DATES = "v.fact_end_date IS NOT NULL AND v.plan_end_date IS NOT NULL"
_MISSING_AREA = (
    "(adm_district IS NULL OR TRIM(adm_district) = '') "
    "AND (district IS NULL OR TRIM(district) = '')"
)
_CHANGE_DAYS = "DATEDIFF(%s, COALESCE(changed_data_work, date_change))"

_FILL_FIELDS = (
    ("address", "Адрес", "text", "all"),
    ("contractor", "Подрядчик", "text", "all"),
    ("customer", "Заказчик", "text", "customer"),
    ("square", "Площадь", "number", "all"),
    ("geometry_2d", "Геометрия", "geometry", "all"),
    ("work_year", "Год работ", "number", "all"),
    ("stage", "Стадия", "text", "all"),
    ("departmental_oiv", "Ведомственный ОИВ", "text", "all"),
    ("program", "Программа", "text", "all"),
    ("customer_smr", "Заказчик СМР", "text", "smr"),
    ("smr_date_plan_beg", "СМР, план начала", "date", "smr"),
    ("smr_date_plan_end", "СМР, план окончания", "date", "smr"),
    ("smr_date_fact_beg", "СМР, факт начала", "date", "smr_done"),
    ("smr_date_fact_end", "СМР, факт окончания", "date", "smr_done"),
)

_CATEGORIES = (
    ("type_object", "Тип объекта"),
    ("category_object_name", "Категория объекта"),
    ("subcategory_object_name", "Подкатегория объекта"),
    ("program", "Программа"),
)

_RULES = (
    ("done_no_fact_end", "Завершена без даты окончания", "Работа в статусе завершения, но fact_end_date пустая.", "critical", "Согласованность"),
    ("cancel_no_reason", "Отменена без причины", "Статус отмены есть, а reason_cansel пустой.", "critical", "Согласованность"),
    ("fact_inverted", "Факт окончания раньше факта начала", "fact_end_date раньше fact_start_date.", "critical", "Согласованность"),
    ("plan_inverted", "План окончания раньше плана начала", "plan_end_date раньше plan_start_date.", "critical", "Согласованность"),
    ("done_no_fact_start", "Завершена без даты начала", "У завершённой работы нет fact_start_date.", "warning", "Согласованность"),
    ("square_non_positive", "Площадь не положительная", "square заполнена и меньше либо равна нулю.", "critical", "Корректность"),
    ("square_mismatch", "Площадь не сходится с текстом", "Число square отличается от square_formatted.", "warning", "Корректность"),
    ("stage_conflict", "Стадия противоречит статусу", "stage и status_id_name указывают на разные исходы.", "critical", "Согласованность"),
    ("year_conflict", "Год работ противоречит тексту года", "Числовой work_year не равен четырёхзначному work_date.", "warning", "Согласованность"),
    ("customer_missing", "Нет заказчика", "У неотменённой работы не заполнен customer.", "warning", "Согласованность"),
    ("stage_dates_missing", "Завершённый этап без фактической даты", "Для предусмотренного ПИР или СМР у завершённой работы нет фактического окончания.", "warning", "Согласованность"),
)


class _LiteralPercentCursor:
    """PyMySQL treats every % as a placeholder. LIKE patterns must survive that."""

    def __init__(self, cursor):
        self._cursor = cursor

    def execute(self, sql, params=None):
        if params is None:
            return self._cursor.execute(sql)
        escaped = sql.replace("%", "%%").replace("%%s", "%s")
        return self._cursor.execute(escaped, params)

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()


def build_insights(cursor, snapshot: date, where: str, params: list) -> dict:
    cursor = _LiteralPercentCursor(cursor)
    latest_sql = _latest_from(where)
    latest_params = _latest_params(snapshot, params)
    metrics = _work_metrics(cursor, latest_sql, latest_params, snapshot)
    fields = _field_fill(cursor, latest_sql, latest_params)
    rules = _rules(metrics)
    version_stats = _version_stats(cursor, snapshot, where, params)
    freshness, avg_days, known = _freshness(cursor, snapshot, where, params)
    metrics["repeated_version_works"] = version_stats["repeated"]
    metrics["works_missing_first_version"] = version_stats["missing_first"]
    metrics["freshness_known"] = known
    metrics["freshness"] = freshness
    quality = _quality(metrics, fields)
    year_versions, year_works = _years(cursor, snapshot, where, params)
    return {
        "works": metrics["works"],
        "rows_without_work_id": _count(
            cursor,
            f"SELECT COUNT(*) AS total FROM krr_work_versions WHERE snapshot_date = %s AND id_work IS NULL {_and(where)}",
            [snapshot, *params],
        ),
        "completed": metrics["completed"],
        "in_progress": metrics["in_progress"],
        "cancelled": metrics["cancelled"],
        "other_stage": metrics["other_stage"],
        "square_sum": metrics["square_sum"],
        "square_avg": metrics["square_avg"],
        "square_known": metrics["square_known"],
        "stage_buckets": [
            {"label": "Завершены", "value": metrics["completed"]},
            {"label": "В работе", "value": metrics["in_progress"]},
            {"label": "Отменены", "value": metrics["cancelled"]},
            {"label": "Прочие", "value": metrics["other_stage"]},
        ],
        "oiv": _distinct_points(cursor, snapshot, where, params, "departmental_oiv"),
        "year_versions": year_versions,
        "year_works": year_works,
        "year_square": _year_square(cursor, latest_sql, latest_params),
        "cancel_reasons": _grouped(
            cursor,
            f"""
            SELECT COALESCE(NULLIF(TRIM(v.reason_cansel), ''), %s) AS label, COUNT(*) AS value
            {latest_sql}
            WHERE {_CANCEL}
            GROUP BY label
            ORDER BY value DESC, label
            LIMIT %s
            """,
            [EMPTY_LABEL, *latest_params, LIST_CAP],
        ),
        "categories": {
            key: _distinct_points(cursor, snapshot, where, params, key)
            for key, _label in _CATEGORIES
        },
        "schedule": metrics["schedule"],
        "quality": quality,
        "fields": fields,
        "rules": rules,
        "version_buckets": version_stats["buckets"],
        "duplicate_id_unique": 0,
        "repeated_version_works": version_stats["repeated"],
        "works_missing_first_version": version_stats["missing_first"],
        "multiple_without_archive": version_stats["without_archive"],
        "actual_flag_available": False,
        "freshness": freshness,
        "freshness_avg_days": avg_days,
        "freshness_known": known,
        "stale_by_oiv": _stale_by_oiv(cursor, snapshot, where, params),
        "missing_area_total": _count(
            cursor,
            f"SELECT COUNT(*) AS total FROM krr_work_versions WHERE snapshot_date = %s AND {_MISSING_AREA} {_and(where)}",
            [snapshot, *params],
        ),
        "missing_area": _missing_area_rows(cursor, snapshot, where, params),
        "unavailable": _unavailable(version_stats["numeric_versions"]),
        "snapshot_note": (
            "Показатели работ считаются по последней версии каждого id_work "
            "в текущем снимке. Это не журнал всех изменений."
        ),
    }


def list_krr_issues(cursor, snapshot: date, where: str, params: list, issue: str, limit: int) -> dict:
    cursor = _LiteralPercentCursor(cursor)
    kind, arg = _split_issue(issue)
    title, count_sql, count_params, list_sql, list_params = _issue_query(
        kind, arg, snapshot, where, params
    )
    total = _count(cursor, count_sql, count_params)
    cursor.execute(list_sql, [*list_params, limit])
    items = []
    for row in cursor.fetchall():
        items.append(
            {
                "id_unique": int(row["id_unique"]),
                "id_work": None if row.get("id_work") is None else int(row["id_work"]),
                "name_work_version": row.get("name_work_version"),
                "address": row.get("address"),
                "stage": row.get("stage"),
                "problem": title,
                "link": row.get("link"),
            }
        )
    return {"total": total, "problem": title, "items": items}


def _work_metrics(cursor, latest_sql: str, latest_params: list, snapshot: date) -> dict:
    day = snapshot.isoformat()
    cursor.execute(
        f"""
        SELECT
          COUNT(*) AS works,
          COALESCE(SUM({_DONE_ONLY}), 0) AS completed,
          COALESCE(SUM({_CANCEL}), 0) AS cancelled,
          COALESCE(SUM({_IN_WORK}), 0) AS in_progress,
          COALESCE(SUM(NOT {_DONE_ONLY} AND NOT {_CANCEL} AND NOT {_IN_WORK}), 0) AS other_stage,
          COALESCE(SUM(v.square IS NOT NULL AND v.square > 0), 0) AS square_known,
          COALESCE(SUM(CASE WHEN v.square IS NOT NULL AND v.square > 0 THEN v.square ELSE 0 END), 0) AS square_sum,
          COALESCE(SUM({_DONE_ONLY} AND v.fact_end_date IS NULL), 0) AS done_no_fact_end,
          COALESCE(SUM({_CANCEL} AND (v.reason_cansel IS NULL OR TRIM(v.reason_cansel) = '')), 0) AS cancel_no_reason,
          COALESCE(SUM(v.fact_start_date IS NOT NULL AND v.fact_end_date IS NOT NULL AND v.fact_end_date < v.fact_start_date), 0) AS fact_inverted,
          COALESCE(SUM(v.plan_start_date IS NOT NULL AND v.plan_end_date IS NOT NULL AND v.plan_end_date < v.plan_start_date), 0) AS plan_inverted,
          COALESCE(SUM({_DONE_ONLY} AND v.fact_start_date IS NULL), 0) AS done_no_fact_start,
          COALESCE(SUM(v.square IS NOT NULL AND v.square <= 0), 0) AS square_non_positive,
          COALESCE(SUM({_square_mismatch()}), 0) AS square_mismatch,
          COALESCE(SUM({_stage_conflict()}), 0) AS stage_conflict,
          COALESCE(SUM(v.work_year IS NOT NULL AND v.work_date REGEXP '^[0-9]{{4}}$' AND CAST(v.work_date AS UNSIGNED) <> v.work_year), 0) AS year_conflict,
          COALESCE(SUM(NOT {_CANCEL} AND (v.customer IS NULL OR TRIM(v.customer) = '')), 0) AS customer_missing,
          COALESCE(SUM({_DONE_ONLY} AND (({_SMR} AND v.smr_date_fact_end IS NULL) OR ({_PIR} AND v.pir_date_fact_end IS NULL))), 0) AS stage_dates_missing,
          COALESCE(SUM({_BOTH_DATES} AND {_DONE_ONLY} AND v.fact_end_date < v.plan_end_date), 0) AS early_done,
          COALESCE(SUM({_BOTH_DATES} AND {_DONE_ONLY} AND v.fact_end_date = v.plan_end_date), 0) AS on_time_done,
          COALESCE(SUM({_BOTH_DATES} AND {_DONE_ONLY} AND v.fact_end_date > v.plan_end_date), 0) AS late_done,
          COALESCE(SUM({_BOTH_DATES} AND {_DONE_ONLY}), 0) AS dated_completed,
          COALESCE(SUM({_BOTH_DATES} AND NOT {_CANCEL} AND v.fact_end_date < v.plan_end_date), 0) AS early,
          COALESCE(SUM({_BOTH_DATES} AND NOT {_CANCEL} AND v.fact_end_date = v.plan_end_date), 0) AS on_time,
          COALESCE(SUM({_BOTH_DATES} AND NOT {_CANCEL} AND v.fact_end_date > v.plan_end_date), 0) AS late,
          COALESCE(SUM(NOT {_CANCEL} AND v.fact_end_date IS NULL), 0) AS unfinished,
          COALESCE(SUM(NOT {_CANCEL} AND v.fact_end_date IS NOT NULL AND v.plan_end_date IS NULL), 0) AS incomplete_dates,
          COALESCE(SUM(NOT {_DONE_ONLY} AND NOT {_CANCEL} AND v.fact_end_date IS NULL AND v.plan_end_date IS NOT NULL AND v.plan_end_date < '{day}'), 0) AS overdue_open,
          AVG(CASE WHEN {_BOTH_DATES} AND {_DONE_ONLY} THEN DATEDIFF(v.fact_end_date, v.plan_end_date) END) AS avg_deviation,
          AVG(CASE WHEN {_DONE_ONLY} AND v.fact_start_date IS NOT NULL AND v.fact_end_date IS NOT NULL AND v.fact_end_date >= v.fact_start_date THEN DATEDIFF(v.fact_end_date, v.fact_start_date) END) AS avg_duration,
          COALESCE(SUM({_consistency_any()}), 0) AS consistency_rows,
          COALESCE(SUM(({_square_mismatch()}) OR (v.square IS NOT NULL AND v.square <= 0)), 0) AS correctness_rows
        {latest_sql}
        """,
        latest_params,
    )
    row = cursor.fetchone() or {}
    works = _int(row.get("works"))
    square_known = _int(row.get("square_known"))
    square_sum = float(row.get("square_sum") or 0) if square_known else None
    dated = _int(row.get("dated_completed"))
    completed = _int(row.get("completed"))
    return {
        "works": works,
        "completed": completed,
        "cancelled": _int(row.get("cancelled")),
        "in_progress": _int(row.get("in_progress")),
        "other_stage": _int(row.get("other_stage")),
        "square_known": square_known,
        "square_sum": square_sum,
        "square_avg": (square_sum / square_known) if square_known and square_sum is not None else None,
        "done_no_fact_end": _int(row.get("done_no_fact_end")),
        "cancel_no_reason": _int(row.get("cancel_no_reason")),
        "fact_inverted": _int(row.get("fact_inverted")),
        "plan_inverted": _int(row.get("plan_inverted")),
        "done_no_fact_start": _int(row.get("done_no_fact_start")),
        "square_non_positive": _int(row.get("square_non_positive")),
        "square_mismatch": _int(row.get("square_mismatch")),
        "stage_conflict": _int(row.get("stage_conflict")),
        "year_conflict": _int(row.get("year_conflict")),
        "customer_missing": _int(row.get("customer_missing")),
        "stage_dates_missing": _int(row.get("stage_dates_missing")),
        "consistency_rows": _int(row.get("consistency_rows")),
        "correctness_rows": _int(row.get("correctness_rows")),
        "schedule": {
            "early": _int(row.get("early")),
            "on_time": _int(row.get("on_time")),
            "late": _int(row.get("late")),
            "unfinished": _int(row.get("unfinished")),
            "incomplete_dates": _int(row.get("incomplete_dates")),
            "overdue_open": _int(row.get("overdue_open")),
            "dated_completed": dated,
            "early_share": _share(_int(row.get("early_done")), dated),
            "on_time_share": _share(_int(row.get("on_time_done")), dated),
            "late_share": _share(_int(row.get("late_done")), dated),
            "avg_deviation_days": _float_or_none(row.get("avg_deviation"), dated),
            "avg_duration_days": _float_or_none(row.get("avg_duration"), completed),
        },
    }


def _field_fill(cursor, latest_sql: str, latest_params: list) -> list[dict]:
    selects = []
    for key, _label, kind, scope in _FILL_FIELDS:
        filled = _filled_sql(key, kind)
        scope_sql = _scope_sql(scope)
        selects.append(f"COALESCE(SUM({scope_sql}), 0) AS app_{key}")
        selects.append(f"COALESCE(SUM({scope_sql} AND {filled}), 0) AS filled_{key}")
    cursor.execute(f"SELECT {', '.join(selects)} {latest_sql}", latest_params)
    raw = cursor.fetchone() or {}
    items = []
    for key, label, _kind, _scope in _FILL_FIELDS:
        applicable = _int(raw.get(f"app_{key}"))
        filled = _int(raw.get(f"filled_{key}"))
        items.append(
            {
                "key": key,
                "label": label,
                "filled": filled,
                "empty": max(0, applicable - filled),
                "applicable": applicable,
                "percent": _share(filled, applicable),
            }
        )
    return items


def _rules(metrics: dict) -> list[dict]:
    return [
        {
            "code": code,
            "title": title,
            "description": description,
            "count": metrics[code],
            "severity": severity,
            "group": group,
        }
        for code, title, description, severity, group in _RULES
    ]


def _quality(metrics: dict, fields: list[dict]) -> dict:
    works = metrics["works"]
    percents = [item["percent"] for item in fields if item["percent"] is not None and item["applicable"]]
    completeness = round(sum(percents) / len(percents), 1) if percents else None
    correctness = _inverse_share(metrics["correctness_rows"], works)
    consistency = _inverse_share(metrics["consistency_rows"], works)
    recent = sum(
        item["value"]
        for item in metrics.get("freshness") or []
        if item["label"] in {"До 30 дней", "30–90 дней", "90–180 дней"}
    )
    freshness = _share(recent, metrics.get("freshness_known") or 0)
    uniqueness = None
    if works:
        penalty = metrics.get("repeated_version_works") or 0
        missing_first = metrics.get("works_missing_first_version")
        if missing_first is not None:
            penalty += missing_first
        uniqueness = round(max(0.0, 100 - (min(works, penalty) / works) * 100), 1)
    parts = {
        "completeness": completeness,
        "correctness": correctness,
        "consistency": consistency,
        "freshness": freshness,
        "uniqueness": uniqueness,
    }
    weight_sum = sum(QUALITY_WEIGHTS[key] for key, value in parts.items() if value is not None)
    score = None
    if weight_sum:
        score = round(
            sum(parts[key] * QUALITY_WEIGHTS[key] for key in parts if parts[key] is not None) / weight_sum,
            1,
        )
    return {"score": score, "weights": dict(QUALITY_WEIGHTS), **parts}


def _version_stats(cursor, snapshot: date, where: str, params: list) -> dict:
    base = [snapshot, *params]
    cursor.execute(
        f"""
        SELECT
          CASE
            WHEN cnt = 1 THEN '1 версия'
            WHEN cnt = 2 THEN '2 версии'
            WHEN cnt = 3 THEN '3 версии'
            WHEN cnt = 4 THEN '4 версии'
            ELSE '5 и более'
          END AS label,
          COUNT(*) AS value
        FROM (
          SELECT id_work, COUNT(*) AS cnt
          FROM krr_work_versions
          WHERE snapshot_date = %s AND id_work IS NOT NULL {_and(where)}
          GROUP BY id_work
        ) counts
        GROUP BY label
        """,
        base,
    )
    found = {row["label"]: _int(row["value"]) for row in cursor.fetchall()}
    buckets = [
        {"label": label, "value": found.get(label, 0)}
        for label in ("1 версия", "2 версии", "3 версии", "4 версии", "5 и более")
    ]
    repeated = _count(
        cursor,
        f"""
        SELECT COUNT(*) AS total FROM (
          SELECT id_work
          FROM krr_work_versions
          WHERE snapshot_date = %s AND id_work IS NOT NULL
            AND version IS NOT NULL AND TRIM(version) <> '' {_and(where)}
          GROUP BY id_work, version
          HAVING COUNT(*) > 1
        ) duplicates
        """,
        base,
    )
    cursor.execute(
        f"""
        SELECT
          COALESCE(SUM(has_numeric), 0) AS numeric_versions,
          COALESCE(SUM(has_numeric AND min_num > 1), 0) AS missing_first
        FROM (
          SELECT
            SUM(version REGEXP '^[0-9]+$') > 0 AS has_numeric,
            MIN(CASE WHEN version REGEXP '^[0-9]+$' THEN CAST(version AS UNSIGNED) END) AS min_num
          FROM krr_work_versions
          WHERE snapshot_date = %s AND id_work IS NOT NULL {_and(where)}
          GROUP BY id_work
        ) versions
        """,
        base,
    )
    version_row = cursor.fetchone() or {}
    numeric = _int(version_row.get("numeric_versions"))
    without_archive = _count(
        cursor,
        f"""
        SELECT COUNT(*) AS total FROM (
          SELECT id_work
          FROM krr_work_versions
          WHERE snapshot_date = %s AND id_work IS NOT NULL AND date_archive IS NULL {_and(where)}
          GROUP BY id_work
          HAVING COUNT(*) > 1
        ) open_groups
        """,
        base,
    )
    return {
        "buckets": buckets,
        "repeated": repeated,
        "missing_first": _int(version_row.get("missing_first")) if numeric else None,
        "numeric_versions": numeric,
        "without_archive": without_archive,
    }


def _freshness(cursor, snapshot: date, where: str, params: list) -> tuple[list[dict], float | None, int]:
    cursor.execute(
        f"""
        SELECT
          COALESCE(SUM(d IS NULL), 0) AS unknown,
          COALESCE(SUM(d IS NOT NULL AND d <= 30), 0) AS d30,
          COALESCE(SUM(d > 30 AND d <= 90), 0) AS d90,
          COALESCE(SUM(d > 90 AND d <= 180), 0) AS d180,
          COALESCE(SUM(d > 180 AND d <= 365), 0) AS d365,
          COALESCE(SUM(d > 365), 0) AS older,
          AVG(d) AS avg_days,
          COALESCE(SUM(d IS NOT NULL), 0) AS known
        FROM (
          SELECT {_CHANGE_DAYS} AS d
          FROM krr_work_versions
          WHERE snapshot_date = %s {_and(where)}
        ) ages
        """,
        [snapshot, snapshot, *params],
    )
    row = cursor.fetchone() or {}
    known = _int(row.get("known"))
    buckets = [
        {"label": "До 30 дней", "value": _int(row.get("d30"))},
        {"label": "30–90 дней", "value": _int(row.get("d90"))},
        {"label": "90–180 дней", "value": _int(row.get("d180"))},
        {"label": "180–365 дней", "value": _int(row.get("d365"))},
        {"label": "Более года", "value": _int(row.get("older"))},
        {"label": "Дата неизвестна", "value": _int(row.get("unknown"))},
    ]
    return buckets, _float_or_none(row.get("avg_days"), known), known


def _years(cursor, snapshot: date, where: str, params: list) -> tuple[list[dict], list[dict]]:
    cursor.execute(
        f"""
        SELECT
          COALESCE(CAST(work_year AS CHAR), %s) AS label,
          COUNT(*) AS versions,
          COUNT(DISTINCT id_work) AS works
        FROM krr_work_versions
        WHERE snapshot_date = %s {_and(where)}
        GROUP BY label
        ORDER BY label
        """,
        [EMPTY_LABEL, snapshot, *params],
    )
    versions = []
    works = []
    for row in cursor.fetchall():
        versions.append({"label": str(row["label"]), "value": _int(row["versions"])})
        works.append({"label": str(row["label"]), "value": _int(row["works"])})
    return versions, works


def _year_square(cursor, latest_sql: str, latest_params: list) -> list[dict]:
    cursor.execute(
        f"""
        SELECT COALESCE(CAST(v.work_year AS CHAR), %s) AS label,
               ROUND(COALESCE(SUM(CASE WHEN v.square > 0 THEN v.square ELSE 0 END), 0)) AS value
        {latest_sql}
        GROUP BY label
        ORDER BY label
        """,
        [EMPTY_LABEL, *latest_params],
    )
    return [{"label": str(row["label"]), "value": _int(row["value"])} for row in cursor.fetchall()]


def _stale_by_oiv(cursor, snapshot: date, where: str, params: list) -> list[dict]:
    return _grouped(
        cursor,
        f"""
        SELECT COALESCE(NULLIF(TRIM(departmental_oiv), ''), %s) AS label, COUNT(*) AS value
        FROM krr_work_versions
        WHERE snapshot_date = %s {_and(where)}
          AND {_CHANGE_DAYS} > 365
        GROUP BY label
        ORDER BY value DESC, label
        LIMIT 12
        """,
        [EMPTY_LABEL, snapshot, *params, snapshot],
    )


def _distinct_points(cursor, snapshot: date, where: str, params: list, column: str) -> list[dict]:
    if column not in {key for key, _label in _CATEGORIES} and column != "departmental_oiv":
        return []
    return _grouped(
        cursor,
        f"""
        SELECT COALESCE(NULLIF(TRIM(CAST(`{column}` AS CHAR)), ''), %s) AS label,
               COUNT(DISTINCT id_work) AS value
        FROM krr_work_versions
        WHERE snapshot_date = %s AND id_work IS NOT NULL {_and(where)}
        GROUP BY label
        ORDER BY value DESC, label
        LIMIT %s
        """,
        [EMPTY_LABEL, snapshot, *params, LIST_CAP],
    )


def _missing_area_rows(cursor, snapshot: date, where: str, params: list) -> list[dict]:
    cursor.execute(
        f"""
        SELECT id_unique, id_work, name_work_version, address, stage, link
        FROM krr_work_versions
        WHERE snapshot_date = %s AND {_MISSING_AREA} {_and(where)}
        ORDER BY id_unique DESC
        LIMIT 100
        """,
        [snapshot, *params],
    )
    return [_public_row(row) for row in cursor.fetchall()]


def _issue_query(kind: str, arg: str, snapshot: date, where: str, params: list):
    latest_sql = _latest_from(where)
    latest_params = _latest_params(snapshot, params)
    if kind == "rule":
        predicate = _rule_predicate(arg)
        title = next(item[1] for item in _RULES if item[0] == arg)
        return _pack(_latest_issue(title, predicate, latest_sql, latest_params))
    if kind == "field":
        field = next((item for item in _FILL_FIELDS if item[0] == arg), None)
        if field is None:
            _unknown()
        key, label, field_kind, scope = field
        predicate = f"{_scope_sql(scope)} AND NOT ({_filled_sql(key, field_kind)})"
        return _pack(_latest_issue(f"Не заполнено: {label}", predicate, latest_sql, latest_params))
    if kind == "stage":
        predicate = {
            "Завершены": _DONE_ONLY,
            "В работе": _IN_WORK,
            "Отменены": _CANCEL,
            "Прочие": f"NOT {_DONE_ONLY} AND NOT {_CANCEL} AND NOT {_IN_WORK}",
        }.get(arg)
        if predicate is None:
            _unknown()
        return _pack(_latest_issue(arg, predicate, latest_sql, latest_params))
    if kind == "schedule":
        predicate = {
            "early": f"{_BOTH_DATES} AND NOT {_CANCEL} AND v.fact_end_date < v.plan_end_date",
            "on_time": f"{_BOTH_DATES} AND NOT {_CANCEL} AND v.fact_end_date = v.plan_end_date",
            "late": f"{_BOTH_DATES} AND NOT {_CANCEL} AND v.fact_end_date > v.plan_end_date",
            "unfinished": f"NOT {_CANCEL} AND v.fact_end_date IS NULL",
            "incomplete": f"NOT {_CANCEL} AND v.fact_end_date IS NOT NULL AND v.plan_end_date IS NULL",
        }.get(arg)
        titles = {
            "early": "Досрочно",
            "on_time": "В срок",
            "late": "С опозданием",
            "unfinished": "Не завершены",
            "incomplete": "Неполные даты",
        }
        if predicate is None:
            _unknown()
        return _pack(_latest_issue(titles[arg], predicate, latest_sql, latest_params))
    if kind == "cancel":
        if arg == EMPTY_LABEL:
            predicate = f"{_CANCEL} AND (v.reason_cansel IS NULL OR TRIM(v.reason_cansel) = '')"
            return _pack(_latest_issue("Причина отмены не указана", predicate, latest_sql, latest_params))
        predicate = f"{_CANCEL} AND TRIM(v.reason_cansel) = %s"
        return _pack(_latest_issue(arg, predicate, latest_sql, [*latest_params, arg]))
    if kind in {"oiv", "category"}:
        if kind == "category" and ":" not in arg:
            _unknown()
        column = "departmental_oiv" if kind == "oiv" else arg.split(":", 1)[0]
        label = arg if kind == "oiv" else arg.split(":", 1)[1]
        if kind == "category" and column not in {key for key, _name in _CATEGORIES}:
            _unknown()
        blank = f"(v.`{column}` IS NULL OR TRIM(CAST(v.`{column}` AS CHAR)) = '')"
        if label == EMPTY_LABEL:
            predicate = blank
        else:
            predicate = f"TRIM(CAST(v.`{column}` AS CHAR)) = %s"
            latest_params = [*latest_params, label]
        return _pack(_latest_issue(label, predicate, latest_sql, latest_params))
    if kind == "year":
        if ":" not in arg:
            _unknown()
        metric, label = arg.split(":", 1)
        if metric == "versions":
            clause, year_params = _year_clause(label, alias="")
            title = f"Версии {label}"
            count_sql = f"SELECT COUNT(*) AS total FROM krr_work_versions WHERE snapshot_date = %s AND {clause} {_and(where)}"
            list_sql = _row_select("") + f" FROM krr_work_versions WHERE snapshot_date = %s AND {clause} {_and(where)} ORDER BY id_unique DESC LIMIT %s"
            sql_params = [snapshot, *year_params, *params]
            return title, count_sql, sql_params, list_sql, sql_params
        clause, year_params = _year_clause(label, alias="v.")
        return _pack(_latest_issue(f"Работы {label}", clause, latest_sql, [*latest_params, *year_params]))
    if kind == "freshness":
        clause = {
            "До 30 дней": "d IS NOT NULL AND d <= 30",
            "30–90 дней": "d > 30 AND d <= 90",
            "90–180 дней": "d > 90 AND d <= 180",
            "180–365 дней": "d > 180 AND d <= 365",
            "Более года": "d > 365",
            "Дата неизвестна": "d IS NULL",
        }.get(arg)
        if clause is None:
            _unknown()
        scope = f"snapshot_date = %s {_and(where)}"
        count_sql = f"SELECT COUNT(*) AS total FROM (SELECT {_CHANGE_DAYS} AS d FROM krr_work_versions WHERE {scope}) ages WHERE {clause}"
        list_sql = (
            _row_select("")
            + f" FROM krr_work_versions WHERE snapshot_date = %s {_and(where)} AND id_unique IN ("
            + f"SELECT id_unique FROM (SELECT id_unique, {_CHANGE_DAYS} AS d FROM krr_work_versions WHERE {scope}) ages WHERE {clause}"
            + ") ORDER BY id_unique DESC LIMIT %s"
        )
        count_params = [snapshot, snapshot, *params]
        list_params = [snapshot, *params, snapshot, snapshot, *params]
        return arg, count_sql, count_params, list_sql, list_params
    if kind == "versions":
        having = {
            "1 версия": "cnt = 1",
            "2 версии": "cnt = 2",
            "3 версии": "cnt = 3",
            "4 версии": "cnt = 4",
            "5 и более": "cnt >= 5",
        }.get(arg)
        if having is None:
            _unknown()
        grouped = f"""
            SELECT id_work, COUNT(*) AS cnt, MAX(id_unique) AS id_unique
            FROM krr_work_versions
            WHERE snapshot_date = %s AND id_work IS NOT NULL {_and(where)}
            GROUP BY id_work
            HAVING {having}
        """
        count_sql = f"SELECT COUNT(*) AS total FROM ({grouped}) groups"
        list_sql = (
            _row_select("v.")
            + f" FROM krr_work_versions v INNER JOIN ({grouped}) picked ON picked.id_unique = v.id_unique AND v.snapshot_date = %s ORDER BY v.id_unique DESC LIMIT %s"
        )
        sql_params = [snapshot, *params]
        return arg, count_sql, sql_params, list_sql, [*sql_params, snapshot]
    if kind == "missing_area":
        count_sql = f"SELECT COUNT(*) AS total FROM krr_work_versions WHERE snapshot_date = %s AND {_MISSING_AREA} {_and(where)}"
        list_sql = _row_select("") + f" FROM krr_work_versions WHERE snapshot_date = %s AND {_MISSING_AREA} {_and(where)} ORDER BY id_unique DESC LIMIT %s"
        shared = [snapshot, *params]
        return "Нет округа и района", count_sql, shared, list_sql, shared
    if kind == "stale_oiv":
        label_sql, label_params = _label_match("departmental_oiv", arg, alias="")
        count_sql = (
            f"SELECT COUNT(*) AS total FROM krr_work_versions WHERE snapshot_date = %s {_and(where)} "
            f"AND {_CHANGE_DAYS} > 365 AND {label_sql}"
        )
        list_sql = (
            _row_select("")
            + f" FROM krr_work_versions WHERE snapshot_date = %s {_and(where)} AND {_CHANGE_DAYS} > 365 AND {label_sql} ORDER BY id_unique DESC LIMIT %s"
        )
        sql_params = [snapshot, *params, snapshot, *label_params]
        return f"Без изменений больше года: {arg}", count_sql, sql_params, list_sql, sql_params
    _unknown()


def _pack(payload: tuple) -> tuple:
    title, count_sql, list_sql, params = payload
    return title, count_sql, params, list_sql, params


def _latest_issue(title: str, predicate: str, latest_sql: str, params: list):
    count_sql = f"SELECT COUNT(*) AS total {latest_sql} WHERE {predicate}"
    list_sql = _row_select("v.") + f" {latest_sql} WHERE {predicate} ORDER BY v.id_unique DESC LIMIT %s"
    return title, count_sql, list_sql, params


def _rule_predicate(code: str) -> str:
    predicates = {
        "done_no_fact_end": f"{_DONE_ONLY} AND v.fact_end_date IS NULL",
        "cancel_no_reason": f"{_CANCEL} AND (v.reason_cansel IS NULL OR TRIM(v.reason_cansel) = '')",
        "fact_inverted": "v.fact_start_date IS NOT NULL AND v.fact_end_date IS NOT NULL AND v.fact_end_date < v.fact_start_date",
        "plan_inverted": "v.plan_start_date IS NOT NULL AND v.plan_end_date IS NOT NULL AND v.plan_end_date < v.plan_start_date",
        "done_no_fact_start": f"{_DONE_ONLY} AND v.fact_start_date IS NULL",
        "square_non_positive": "v.square IS NOT NULL AND v.square <= 0",
        "square_mismatch": _square_mismatch(),
        "stage_conflict": _stage_conflict(),
        "year_conflict": "v.work_year IS NOT NULL AND v.work_date REGEXP '^[0-9]{4}$' AND CAST(v.work_date AS UNSIGNED) <> v.work_year",
        "customer_missing": f"NOT {_CANCEL} AND (v.customer IS NULL OR TRIM(v.customer) = '')",
        "stage_dates_missing": f"{_DONE_ONLY} AND (({_SMR} AND v.smr_date_fact_end IS NULL) OR ({_PIR} AND v.pir_date_fact_end IS NULL))",
    }
    predicate = predicates.get(code)
    if predicate is None:
        _unknown()
    return predicate


def _year_clause(label: str, alias: str) -> tuple[str, list]:
    if label == EMPTY_LABEL:
        return f"{alias}work_year IS NULL", []
    if label.isdigit():
        return f"{alias}work_year = %s", [int(label)]
    _unknown()
    return "1=0", []


def _label_match(column: str, label: str, alias: str) -> tuple[str, list]:
    target = f"{alias}`{column}`" if alias else f"`{column}`"
    if label == EMPTY_LABEL:
        return f"({target} IS NULL OR TRIM(CAST({target} AS CHAR)) = '')", []
    return f"TRIM(CAST({target} AS CHAR)) = %s", [label]


def _split_issue(issue: str) -> tuple[str, str]:
    text = (issue or "").strip()
    if ":" not in text or len(text) > 300:
        _unknown()
    kind, arg = text.split(":", 1)
    if not kind or not arg:
        _unknown()
    return kind, arg


def _unknown() -> None:
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неизвестный показатель детализации.")


def _latest_from(where: str) -> str:
    return f"""
        FROM krr_work_versions v
        INNER JOIN (
          SELECT id_work, MAX(id_unique) AS id_unique
          FROM krr_work_versions
          WHERE snapshot_date = %s AND id_work IS NOT NULL {_and(where)}
          GROUP BY id_work
        ) latest ON latest.id_unique = v.id_unique AND v.snapshot_date = %s
    """


def _latest_params(snapshot: date, params: list) -> list:
    return [snapshot, *params, snapshot]


def _and(where: str) -> str:
    return f"AND {where}" if where else ""


def _row_select(alias: str) -> str:
    return (
        f"SELECT {alias}id_unique, {alias}id_work, {alias}name_work_version, "
        f"{alias}address, {alias}stage, {alias}link"
    )


def _public_row(row: dict) -> dict:
    return {
        "id_unique": int(row["id_unique"]),
        "id_work": None if row.get("id_work") is None else int(row["id_work"]),
        "name_work_version": row.get("name_work_version"),
        "address": row.get("address"),
        "stage": row.get("stage"),
        "link": row.get("link"),
    }


def _scope_sql(scope: str) -> str:
    if scope == "customer":
        return f"(NOT {_CANCEL})"
    if scope == "smr":
        return f"({_SMR})"
    if scope == "smr_done":
        return f"({_DONE_ONLY} AND {_SMR})"
    return "(1=1)"


def _filled_sql(key: str, kind: str) -> str:
    if kind == "date" or kind == "number":
        return f"v.`{key}` IS NOT NULL"
    if kind == "geometry":
        return f"(v.`{key}` IS NOT NULL AND CHAR_LENGTH(v.`{key}`) > 0)"
    return f"(v.`{key}` IS NOT NULL AND TRIM(CAST(v.`{key}` AS CHAR)) <> '')"


def _square_mismatch() -> str:
    return (
        "v.square IS NOT NULL AND v.square_formatted IS NOT NULL AND TRIM(v.square_formatted) <> '' "
        "AND ("
        "TRIM(v.square_formatted) NOT REGEXP '^[0-9 ]+([.,][0-9]+)?$' "
        "OR ABS(v.square - CAST(REPLACE(REPLACE(REPLACE(TRIM(v.square_formatted), ' ', ''), '\u00a0', ''), ',', '.') AS DECIMAL(18,3))) > 0.05"
        ")"
    )


def _stage_conflict() -> str:
    done_stage = "LOWER(COALESCE(v.stage, '')) LIKE '%заверш%'"
    done_status = "LOWER(COALESCE(v.status_id_name, '')) LIKE '%заверш%'"
    cancel_stage = "LOWER(COALESCE(v.stage, '')) LIKE '%отмен%'"
    cancel_status = "LOWER(COALESCE(v.status_id_name, '')) LIKE '%отмен%'"
    work_stage = "LOWER(COALESCE(v.stage, '')) LIKE '%в работе%'"
    work_status = "LOWER(COALESCE(v.status_id_name, '')) LIKE '%в работе%'"
    return (
        f"(({done_stage}) AND (({cancel_status}) OR ({work_status}))) "
        f"OR (({done_status}) AND (({cancel_stage}) OR ({work_stage}))) "
        f"OR (({cancel_stage}) AND ({done_status})) "
        f"OR (({cancel_status}) AND ({done_stage}))"
    )


def _consistency_any() -> str:
    return "(" + " OR ".join(f"({_rule_predicate(code)})" for code, *_rest in _RULES if code not in {"square_non_positive", "square_mismatch"}) + ")"


def _grouped(cursor, sql: str, params: list) -> list[dict]:
    cursor.execute(sql, params)
    return [{"label": str(row["label"]), "value": _int(row["value"])} for row in cursor.fetchall()]


def _count(cursor, sql: str, params: list) -> int:
    cursor.execute(sql, params)
    return _int((cursor.fetchone() or {}).get("total"))


def _unavailable(numeric_versions: int) -> list[str]:
    notes = [
        "Поля card_type_name в наборе нет, распределение по типу карточки недоступно.",
        "id и id_work — разные идентификаторы (id исходной записи и id работы), их неравенство не считается ошибкой.",
        "Признака актуальной версии нет. Дата архива не используется как такой признак.",
        "Текущая выборка — снимок версий, а не полная история создания и редактирования.",
    ]
    if not numeric_versions:
        notes.append("Проверка отсутствия первой версии недоступна: номера version не числовые.")
    return notes


def _share(part: int, total: int) -> float | None:
    if not total:
        return None
    return round(part / total * 100, 1)


def _inverse_share(errors: int, total: int) -> float | None:
    if not total:
        return None
    return round(max(0.0, 100 - errors / total * 100), 1)


def _float_or_none(value, known: int) -> float | None:
    if not known or value is None:
        return None
    return round(float(value), 1)


def _int(value) -> int:
    if value is None:
        return 0
    return int(value)
