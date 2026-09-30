from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock
from time import monotonic

from app.config import settings
from app.services.analytics_processor import build_dataset
from app.services.analytics_queries import AnalyticsFilterSpec, query_dashboard
from app.services.google_sheets_client import (
    GoogleSheetsConfigError,
    google_sheets_client,
)


class AnalyticsNotConfiguredError(RuntimeError):
    pass


@dataclass(frozen=True)
class _CachedDataset:
    payload: dict
    expires_at: float


class AnalyticsService:
    def __init__(self) -> None:
        self._lock = Lock()
        self._cache: _CachedDataset | None = None

    def query(
        self,
        spec: AnalyticsFilterSpec,
        *,
        table_limit: int,
        table_offset: int,
        refresh: bool = False,
        allow_stale: bool = False,
    ) -> dict:
        dataset = self._load(refresh=refresh, allow_stale=allow_stale)
        return {
            "spreadsheet_id": dataset["spreadsheet_id"],
            "sheet_name": dataset["sheet_name"],
            "fetched_at": dataset["fetched_at"],
            "itsm_base_url": settings.analytics_itsm_base_url,
            **query_dashboard(
                dataset,
                spec,
                table_limit=table_limit,
                table_offset=table_offset,
            ),
        }

    def get_applications(self, *, refresh: bool = False) -> dict:
        dataset = self._load(refresh=refresh, allow_stale=False)
        return {
            "spreadsheet_id": dataset["spreadsheet_id"],
            "sheet_name": dataset["sheet_name"],
            "fetched_at": dataset["fetched_at"],
            "total": len(dataset["tickets"]),
            "applications": dataset["tickets"],
        }

    def _load(self, *, refresh: bool, allow_stale: bool) -> dict:
        if not refresh:
            cached = self._read_cache(allow_stale=allow_stale)
            if cached is not None:
                return cached

        payload = self._fetch_and_parse()
        self._write_cache(payload)
        return payload

    def _fetch_and_parse(self) -> dict:
        spreadsheet_id = settings.google_sheets_spreadsheet_id.strip()
        sheet_name = settings.google_sheets_sheet_name.strip()
        if not spreadsheet_id or not sheet_name:
            raise AnalyticsNotConfiguredError(
                "GOOGLE_SHEETS_SPREADSHEET_ID and GOOGLE_SHEETS_SHEET_NAME are required"
            )

        try:
            values = google_sheets_client.fetch_sheet_values(
                spreadsheet_id, sheet_name
            )
        except GoogleSheetsConfigError as exc:
            raise AnalyticsNotConfiguredError(str(exc)) from exc

        return {
            "spreadsheet_id": spreadsheet_id,
            "sheet_name": sheet_name,
            "fetched_at": datetime.now(timezone.utc),
            **build_dataset(values),
        }

    def _read_cache(self, *, allow_stale: bool) -> dict | None:
        with self._lock:
            if self._cache is None:
                return None
            if not allow_stale and monotonic() >= self._cache.expires_at:
                return None
            return self._cache.payload

    def _write_cache(self, payload: dict) -> None:
        ttl = max(settings.google_sheets_cache_ttl_seconds, 0)
        with self._lock:
            self._cache = _CachedDataset(
                payload=payload,
                expires_at=monotonic() + ttl,
            )


analytics_service = AnalyticsService()
