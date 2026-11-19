"""Загрузка версий работ КРР из DTW и два суточных снимка.

Продакшен-сервер не видит DTW. Снимок забирает Flutter-клиент из
корпоративной сети и страницами отдаёт его сюда.
"""

import logging
import threading
import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any, Literal

from app.config import settings
from app.db import get_db
from app.services.analytics_processor import analytics_now
from app.services.dtw_client import DtwClient, DtwError, DtwNotConfiguredError
from app.services.krr_records import encode_row, upsert_sql

logger = logging.getLogger(__name__)

_BATCH_SIZE = 40
_MAX_PAGES = 500
_DB_TIMEOUT = 120
# DTW itself accepts this page size. The browser splits each page into
# smaller posts before the request reaches the proxy.
_RELAY_PAGE_SIZE = 1000

_SUMMARY_COLUMNS = """
id_unique, name_work_version, id_work, work_year, stage, stage_id,
adm_district, district, address, dk, square, status_id_name, program,
category_object, link, customer, activation_status,
plan_start_date, plan_end_date, fact_start_date, fact_end_date
"""

_UPSERT_SQL = upsert_sql()


class KrrSyncInProgressError(RuntimeError):
    def __init__(self) -> None:
        super().__init__("Загрузка набора КРР уже выполняется.")


class KrrRelayError(RuntimeError):
    def __init__(self, message: str, status_code: int = 409) -> None:
        self.status_code = status_code
        super().__init__(message)


class KrrDatasetService:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._relay_token: str | None = None
        self._relay_seen: set[tuple[int | None, ...]] = set()

    def start_sync(self, *, force: bool = False) -> tuple[dict[str, Any], bool]:
        today = _today()
        with self._lock:
            if self._thread is not None and self._thread.is_alive():
                raise KrrSyncInProgressError()
            if self._relay_token:
                raise KrrSyncInProgressError()
            if not force and self._snapshot_status(today) == "succeeded":
                return self.status(fetched_from_api=False), False
            if not settings.dtw_login.strip() or not settings.dtw_password:
                raise DtwNotConfiguredError()
            self._mark_running(today)
            self._thread = threading.Thread(
                target=self._sync,
                args=(today,),
                name="krr-sync",
                daemon=True,
            )
            self._thread.start()
        return self.status(fetched_from_api=True), True

    def begin_client_sync(self, *, force: bool = False) -> dict[str, Any]:
        today = _today()
        with self._lock:
            if self._thread is not None and self._thread.is_alive():
                raise KrrSyncInProgressError()
            if not force and self._snapshot_status(today) == "succeeded":
                payload = self.status(fetched_from_api=False)
                payload["needed"] = False
                payload["sync_id"] = ""
                payload["page_size"] = _RELAY_PAGE_SIZE
                payload["offset_param"] = settings.dtw_offset_param
                payload["limit_param"] = settings.dtw_limit_param
                payload["base_url"] = ""
                payload["login"] = ""
                payload["password"] = ""
                return payload
            if not settings.dtw_login.strip() or not settings.dtw_password:
                raise DtwNotConfiguredError()
            self._relay_token = uuid.uuid4().hex
            self._relay_seen = set()
            self._mark_running(today)
            self._clear_snapshot_rows(today)
            payload = self.status(fetched_from_api=False)
            payload.update(
                {
                    "needed": True,
                    "sync_id": self._relay_token,
                    "base_url": settings.dtw_base_url.rstrip("/"),
                    "login": settings.dtw_login.strip(),
                    "password": settings.dtw_password,
                    "page_size": _RELAY_PAGE_SIZE,
                    "offset_param": settings.dtw_offset_param.strip() or "offset",
                    "limit_param": settings.dtw_limit_param.strip() or "limit",
                }
            )
            return payload

    def accept_client_page(
        self,
        *,
        sync_id: str,
        name: str,
        total_count: int,
        rows: list[Any],
        payload: dict[str, Any] | None = None,
        offset: int = 0,
        page_start: bool = False,
        done: bool = False,
    ) -> dict[str, Any]:
        if payload is not None:
            return self._accept_payload(
                sync_id=sync_id,
                offset=offset,
                payload=payload,
                page_start=page_start,
                client_done=done,
            )
        with self._lock:
            snapshot_date = self._require_relay(sync_id)
            accepted = self._insert_rows(rows, snapshot_date)
            stored = self._count_rows(snapshot_date)
            self._update_progress(
                snapshot_date,
                name=name.strip(),
                total=total_count,
                stored=stored,
            )
        return {
            "stored_count": stored,
            "total_count": total_count,
            "accepted": accepted,
            "row_count": len(rows),
            "done": False,
        }

    def finish_client_sync(self, sync_id: str) -> dict[str, Any]:
        with self._lock:
            snapshot_date = self._require_relay(sync_id)
            stored = self._count_rows(snapshot_date)
            if stored <= 0:
                self._relay_token = None
                self._relay_seen = set()
                self._clear_snapshot_rows(snapshot_date)
                self._fail(snapshot_date, "DTW не вернул строк набора КРР.")
                raise KrrRelayError("DTW не вернул строк набора КРР.", 502)
            self._commit(snapshot_date)
            self._relay_token = None
            self._relay_seen = set()
        logger.info("KRR relay stored %s rows for %s", stored, snapshot_date.isoformat())
        return self.status(fetched_from_api=True)

    def abort_client_sync(self, sync_id: str, message: str) -> None:
        text = message.strip() or "Не удалось загрузить набор КРР."
        with self._lock:
            snapshot_date = self._require_relay(sync_id)
            self._relay_token = None
            self._relay_seen = set()
            self._clear_snapshot_rows(snapshot_date)
            self._fail(snapshot_date, text[:2000])
        logger.info("KRR relay aborted: %s", text[:240])

    def status(self, *, fetched_from_api: bool = False) -> dict[str, Any]:
        today = _today()
        yesterday = today - timedelta(days=1)
        stored = self._load_snapshots((today, yesterday))
        return {
            "dataset_id": settings.dtw_dataset_id,
            "fetched_from_api": fetched_from_api,
            "today": _public_snapshot(today, "today", stored.get(today)),
            "yesterday": _public_snapshot(
                yesterday,
                "yesterday",
                stored.get(yesterday),
            ),
        }

    def list_works(
        self,
        *,
        limit: int,
        offset: int,
        snapshot: Literal["today", "yesterday"] = "today",
        work_year: int | None = None,
        stage: str | None = None,
        adm_district: str | None = None,
        district: str | None = None,
        dk: bool | None = None,
        query: str | None = None,
    ) -> dict[str, Any]:
        snapshot_date = _snapshot_day(snapshot)
        if self._snapshot_status(snapshot_date) != "succeeded":
            return {
                "snapshot_date": snapshot_date,
                "total": 0,
                "limit": limit,
                "offset": offset,
                "items": [],
            }

        clauses = ["snapshot_date = %s"]
        params: list[Any] = [snapshot_date]
        if work_year is not None:
            clauses.append("work_year = %s")
            params.append(work_year)
        if stage:
            clauses.append("stage = %s")
            params.append(stage.strip())
        if adm_district:
            clauses.append("adm_district = %s")
            params.append(adm_district.strip())
        if district:
            clauses.append("district = %s")
            params.append(district.strip())
        if dk is not None:
            clauses.append("dk = %s")
            params.append(int(dk))
        if query and query.strip():
            clauses.append(
                "(name_work_version LIKE %s ESCAPE '\\\\' "
                "OR address LIKE %s ESCAPE '\\\\')"
            )
            like = _like(query.strip())
            params.extend((like, like))

        where = " AND ".join(clauses)
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"SELECT COUNT(*) AS total FROM krr_work_versions WHERE {where}",
                    params,
                )
                total = int(cursor.fetchone()["total"])
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS}
                    FROM krr_work_versions
                    WHERE {where}
                    ORDER BY work_year DESC, id_unique DESC
                    LIMIT %s OFFSET %s
                    """,
                    [*params, limit, offset],
                )
                items = cursor.fetchall()
        return {
            "snapshot_date": snapshot_date,
            "total": total,
            "limit": limit,
            "offset": offset,
            "items": items,
        }

    def get_work(
        self,
        id_unique: int,
        *,
        snapshot: Literal["today", "yesterday"] = "today",
    ) -> dict[str, Any] | None:
        snapshot_date = _snapshot_day(snapshot)
        if self._snapshot_status(snapshot_date) != "succeeded":
            return None
        with get_db(read_timeout=_DB_TIMEOUT) as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT *
                    FROM krr_work_versions
                    WHERE snapshot_date = %s AND id_unique = %s
                    """,
                    (snapshot_date, id_unique),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return _public_row(row)

    def _sync(self, snapshot_date: date) -> None:
        try:
            self._clear_snapshot_rows(snapshot_date)
            client = DtwClient()
            stored = self._download(client, snapshot_date)
            self._commit(snapshot_date)
            logger.info(
                "KRR sync stored %s rows for %s",
                stored,
                snapshot_date.isoformat(),
            )
        except Exception as exc:
            logger.exception("KRR dataset sync failed")
            self._clear_snapshot_rows(snapshot_date)
            message = str(exc).strip() or "Не удалось загрузить набор КРР."
            self._fail(snapshot_date, message[:2000])

    def _download(self, client: DtwClient, snapshot_date: date) -> int:
        page_size = max(1, settings.dtw_page_size)
        offset = 0
        total = 0
        stored = 0
        seen_pages: set[tuple[int | None, ...]] = set()
        name = ""

        for _page_number in range(_MAX_PAGES):
            page = client.fetch_page(offset=offset)
            rows = page["data"]
            if not name:
                raw_name = page.get("name")
                name = raw_name.strip() if isinstance(raw_name, str) else ""
            page_total = _as_int(page.get("totalCount"))
            if page_total is not None:
                total = page_total
            if not rows:
                break

            signature = tuple(
                _as_int(row.get("id_unique"))
                for row in rows[:3]
                if isinstance(row, dict)
            )
            if signature in seen_pages:
                raise DtwError(
                    "Сервис DTW вернул повтор страницы. "
                    "Проверьте DTW_OFFSET_PARAM и DTW_LIMIT_PARAM "
                    f"({settings.dtw_offset_param}/{settings.dtw_limit_param})."
                )
            seen_pages.add(signature)

            stored += self._insert_rows(rows, snapshot_date)
            self._update_progress(
                snapshot_date,
                name=name,
                total=total,
                stored=stored,
            )
            offset += len(rows)
            logger.info(
                "KRR page offset=%s rows=%s stored=%s total=%s",
                offset - len(rows),
                len(rows),
                stored,
                total,
            )
            if len(rows) < page_size or (total and offset >= total):
                break
        else:
            raise DtwError("Загрузка КРР остановлена: слишком много страниц.")

        if total and stored < total:
            logger.warning(
                "KRR sync stored %s of %s rows reported by DTW",
                stored,
                total,
            )
        return stored

    def _insert_rows(self, rows: list[Any], snapshot_date: date) -> int:
        encoded: list[tuple] = []
        skipped = 0
        for raw in rows:
            item = encode_row(raw, snapshot_date) if isinstance(raw, dict) else None
            if item is None:
                skipped += 1
                continue
            encoded.append(item)
        if skipped:
            logger.warning("Skipped %s KRR rows without id_unique", skipped)
        if not encoded:
            return 0
        with get_db(read_timeout=_DB_TIMEOUT, write_timeout=_DB_TIMEOUT) as conn:
            with conn.cursor() as cursor:
                for start in range(0, len(encoded), _BATCH_SIZE):
                    cursor.executemany(_UPSERT_SQL, encoded[start : start + _BATCH_SIZE])
        return len(encoded)

    def _commit(self, snapshot_date: date) -> None:
        keep_from = snapshot_date - timedelta(days=1)
        with get_db(write_timeout=_DB_TIMEOUT) as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT COUNT(*) AS row_count
                    FROM krr_work_versions
                    WHERE snapshot_date = %s
                    """,
                    (snapshot_date,),
                )
                stored = int(cursor.fetchone()["row_count"])
                cursor.execute(
                    """
                    UPDATE krr_daily_snapshots
                    SET status = 'succeeded',
                        stored_count = %s,
                        error_message = NULL,
                        finished_at = CURRENT_TIMESTAMP
                    WHERE snapshot_date = %s
                    """,
                    (stored, snapshot_date),
                )
                cursor.execute(
                    "DELETE FROM krr_work_versions WHERE snapshot_date < %s",
                    (keep_from,),
                )
                cursor.execute(
                    "DELETE FROM krr_daily_snapshots WHERE snapshot_date < %s",
                    (keep_from,),
                )

    def _clear_snapshot_rows(self, snapshot_date: date) -> None:
        try:
            with get_db(write_timeout=_DB_TIMEOUT) as conn:
                with conn.cursor() as cursor:
                    cursor.execute(
                        "DELETE FROM krr_work_versions WHERE snapshot_date = %s",
                        (snapshot_date,),
                    )
        except Exception:
            logger.exception("Failed to clear KRR snapshot %s", snapshot_date)

    def _mark_running(self, snapshot_date: date) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO krr_daily_snapshots (
                      snapshot_date, dataset_id, dataset_name, total_count,
                      stored_count, status, error_message, started_at, finished_at
                    )
                    VALUES (%s, %s, '', 0, 0, 'running', NULL, CURRENT_TIMESTAMP, NULL)
                    ON DUPLICATE KEY UPDATE
                      status = 'running',
                      error_message = NULL,
                      stored_count = 0,
                      total_count = 0,
                      started_at = CURRENT_TIMESTAMP,
                      finished_at = NULL
                    """,
                    (snapshot_date, settings.dtw_dataset_id),
                )

    def _update_progress(
        self,
        snapshot_date: date,
        *,
        name: str,
        total: int,
        stored: int,
    ) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE krr_daily_snapshots
                    SET dataset_name = CASE WHEN %s = '' THEN dataset_name ELSE %s END,
                        total_count = %s,
                        stored_count = %s
                    WHERE snapshot_date = %s
                    """,
                    (name, name, total, stored, snapshot_date),
                )

    def _fail(self, snapshot_date: date, message: str) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE krr_daily_snapshots
                    SET status = 'failed',
                        error_message = %s,
                        stored_count = 0,
                        finished_at = CURRENT_TIMESTAMP
                    WHERE snapshot_date = %s
                    """,
                    (message, snapshot_date),
                )

    def _accept_payload(
        self,
        *,
        sync_id: str,
        offset: int,
        payload: dict[str, Any],
        page_start: bool = False,
        client_done: bool = False,
    ) -> dict[str, Any]:
        rows = payload.get("data")
        if not isinstance(rows, list):
            raise KrrRelayError("Ответ набора DTW не содержит список data.", 502)
        if len(rows) > 500:
            raise KrrRelayError("Слишком большая страница DTW.", 502)
        raw_name = payload.get("name")
        name = raw_name.strip() if isinstance(raw_name, str) else ""
        total = _as_int(payload.get("totalCount")) or 0
        signature = tuple(
            _as_int(row.get("id_unique"))
            for row in rows[:3]
            if isinstance(row, dict)
        )
        with self._lock:
            snapshot_date = self._require_relay(sync_id)
            if page_start and signature and signature in self._relay_seen:
                raise KrrRelayError(
                    "Сервис DTW вернул повтор страницы. "
                    "Проверьте DTW_OFFSET_PARAM и DTW_LIMIT_PARAM "
                    f"({settings.dtw_offset_param}/{settings.dtw_limit_param})."
                )
            if page_start and signature:
                self._relay_seen.add(signature)
            accepted = self._insert_rows(rows, snapshot_date) if rows else 0
            stored = self._count_rows(snapshot_date)
            self._update_progress(
                snapshot_date,
                name=name,
                total=total,
                stored=stored,
            )
        row_count = len(rows)
        done = row_count == 0 or client_done or (
            total > 0 and offset + row_count >= total
        )
        return {
            "stored_count": stored,
            "total_count": total,
            "accepted": accepted,
            "row_count": row_count,
            "done": done,
        }

    def _require_relay(self, sync_id: str) -> date:
        if not sync_id or sync_id != self._relay_token:
            raise KrrRelayError(
                "Сессия загрузки устарела. Запустите загрузку заново."
            )
        snapshot_date = _today()
        if self._snapshot_status(snapshot_date) != "running":
            raise KrrRelayError("Загрузка набора КРР не выполняется.")
        return snapshot_date

    def _count_rows(self, snapshot_date: date) -> int:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT COUNT(*) AS row_count
                    FROM krr_work_versions
                    WHERE snapshot_date = %s
                    """,
                    (snapshot_date,),
                )
                return int(cursor.fetchone()["row_count"])

    def _snapshot_status(self, snapshot_date: date) -> str:
        row = self._load_snapshots((snapshot_date,)).get(snapshot_date)
        if row is None:
            return "idle"
        return str(row["status"])

    def _load_snapshots(self, days: tuple[date, ...]) -> dict[date, dict[str, Any]]:
        if not days:
            return {}
        placeholders = ", ".join(["%s"] * len(days))
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT snapshot_date, dataset_name, status, total_count,
                           stored_count, error_message, started_at, finished_at
                    FROM krr_daily_snapshots
                    WHERE snapshot_date IN ({placeholders})
                    """,
                    days,
                )
                rows = cursor.fetchall()
        loaded: dict[date, dict[str, Any]] = {}
        for row in rows:
            day = row["snapshot_date"]
            if isinstance(day, datetime):
                day = day.date()
            row["snapshot_date"] = day
            loaded[day] = row
        return loaded


def _today() -> date:
    return analytics_now().date()


def _snapshot_day(snapshot: Literal["today", "yesterday"]) -> date:
    today = _today()
    return today if snapshot == "today" else today - timedelta(days=1)


def _public_snapshot(
    snapshot_date: date,
    role: Literal["today", "yesterday"],
    row: dict[str, Any] | None,
) -> dict[str, Any]:
    if row is None:
        return {
            "snapshot_date": snapshot_date,
            "role": role,
            "dataset_name": "",
            "status": "idle",
            "total_count": 0,
            "stored_count": 0,
            "error_message": None,
            "started_at": None,
            "finished_at": None,
        }
    return {
        "snapshot_date": row["snapshot_date"],
        "role": role,
        "dataset_name": row["dataset_name"],
        "status": row["status"],
        "total_count": row["total_count"],
        "stored_count": row["stored_count"],
        "error_message": row["error_message"],
        "started_at": row["started_at"],
        "finished_at": row["finished_at"],
    }


def _public_row(row: dict[str, Any]) -> dict[str, Any]:
    item = dict(row)
    item.pop("sync_generation", None)
    item.pop("synced_at", None)
    item["id"] = item.pop("source_id", None)
    item["13048_id_unique"] = item.pop("ref_13048_id", None)
    item["13049_id_unique"] = item.pop("ref_13049_id", None)
    for key, value in list(item.items()):
        if isinstance(value, Decimal):
            item[key] = float(value)
        elif key in {"dk", "geometry_valid"} and value is not None:
            item[key] = bool(value)
    return item


def _like(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def _as_int(value: object) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


krr_dataset_service = KrrDatasetService()
