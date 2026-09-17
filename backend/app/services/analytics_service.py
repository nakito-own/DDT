from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock
from time import monotonic

from app.config import settings
from app.services.analytics_processor import build_dashboard, parse_applications
from app.services.google_sheets_client import (
    GoogleSheetsConfigError,
    google_sheets_client,
)


class AnalyticsNotConfiguredError(RuntimeError):
    pass


@dataclass(frozen=True)
class _CachedPayload:
    payload: dict
    expires_at: float


class AnalyticsService:
    def __init__(self) -> None:
        self._lock = Lock()
        self._cache: _CachedPayload | None = None

    def get_dashboard(self, *, refresh: bool = False) -> dict:
        return self._load(refresh=refresh)

    def get_applications(self, *, refresh: bool = False) -> dict:
        payload = self._load(refresh=refresh)
        return {
            "spreadsheet_id": payload["spreadsheet_id"],
            "sheet_name": payload["sheet_name"],
            "fetched_at": payload["fetched_at"],
            "total": payload["kpis"]["total"],
            "applications": payload["applications"],
        }

    def _load(self, *, refresh: bool) -> dict:
        if not refresh:
            cached = self._read_cache()
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

        parsed = parse_applications(values)
        dashboard = build_dashboard(parsed)
        return {
            "spreadsheet_id": spreadsheet_id,
            "sheet_name": sheet_name,
            "fetched_at": datetime.now(timezone.utc),
            **dashboard,
        }

    def _read_cache(self) -> dict | None:
        with self._lock:
            if self._cache is None:
                return None
            if monotonic() >= self._cache.expires_at:
                self._cache = None
                return None
            return self._cache.payload

    def _write_cache(self, payload: dict) -> None:
        ttl = max(settings.google_sheets_cache_ttl_seconds, 0)
        with self._lock:
            self._cache = _CachedPayload(
                payload=payload,
                expires_at=monotonic() + ttl,
            )


analytics_service = AnalyticsService()
