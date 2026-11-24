"""Короткий кеш ответов дашбордов и один слот на тяжёлый пересчёт.

Одинаковый запрос не считается второй раз, пока первый не закончился.
Разные запросы не запускаются пачкой: слот один на процесс аналитики.
"""

from __future__ import annotations

import json
import threading
import time
from collections import OrderedDict
from collections.abc import Callable
from datetime import date, datetime
from typing import Any, TypeVar

from app.config import settings
from app.services.analytics_queries import AnalyticsFilterSpec

T = TypeVar("T")


class DashboardBusyError(Exception):
    def __init__(self) -> None:
        super().__init__(
            "Дашборд уже считается. Повторите запрос через несколько секунд."
        )


class DashboardTimeoutError(Exception):
    def __init__(self) -> None:
        super().__init__(
            "Расчёт дашборда прерван по лимиту времени. Сузьте фильтр и повторите."
        )


class _Flight:
    def __init__(self) -> None:
        self.event = threading.Event()
        self.value: Any = None
        self.error: BaseException | None = None


class DashboardCache:
    def __init__(self, *, ttl_seconds: int, max_entries: int = 64) -> None:
        self._ttl = max(1, ttl_seconds)
        self._max_entries = max_entries
        self._items: OrderedDict[str, tuple[float, Any]] = OrderedDict()
        self._lock = threading.Lock()
        self._flights: dict[str, _Flight] = {}

    def compute_once(self, key: str, factory: Callable[[], T]) -> T:
        cached = self._read(key)
        if cached is not None:
            return cached

        with self._lock:
            cached = self._read_unlocked(key)
            if cached is not None:
                return cached
            flight = self._flights.get(key)
            if flight is None:
                flight = _Flight()
                self._flights[key] = flight
                leader = True
            else:
                leader = False

        if not leader:
            flight.event.wait(timeout=40)
            if flight.error is not None:
                raise flight.error
            if flight.event.is_set() and flight.value is not None:
                return flight.value
            cached = self._read(key)
            if cached is not None:
                return cached
            raise DashboardBusyError()

        try:
            value = factory()
        except BaseException as exc:
            flight.error = exc
            raise
        else:
            flight.value = value
            self._write(key, value)
            return value
        finally:
            with self._lock:
                self._flights.pop(key, None)
            flight.event.set()

    def _read(self, key: str) -> Any | None:
        with self._lock:
            return self._read_unlocked(key)

    def _read_unlocked(self, key: str) -> Any | None:
        item = self._items.get(key)
        if item is None:
            return None
        expires_at, value = item
        if expires_at <= _monotonic():
            self._items.pop(key, None)
            return None
        self._items.move_to_end(key)
        return value

    def _write(self, key: str, value: Any) -> None:
        with self._lock:
            self._items[key] = (_monotonic() + self._ttl, value)
            self._items.move_to_end(key)
            while len(self._items) > self._max_entries:
                self._items.popitem(last=False)


_slot = threading.Semaphore(1)


def dashboard_slot():
    return _DashboardSlot()


class _DashboardSlot:
    def __enter__(self) -> None:
        timeout = max(0.0, settings.dashboard_queue_timeout_seconds)
        if not _slot.acquire(timeout=timeout):
            raise DashboardBusyError()

    def __exit__(self, exc_type, exc, traceback) -> None:
        _slot.release()


def filter_cache_key(prefix: str, spec: AnalyticsFilterSpec, **parts: Any) -> str:
    payload = {
        "prefix": prefix,
        "date_column": spec.date_column,
        "period_start": _plain(spec.period_start),
        "period_end": _plain(spec.period_end),
        "selected": {key: list(values) for key, values in sorted(spec.selected.items())},
        "queries": {key: value for key, value in sorted(spec.queries.items())},
        "exclude_weekends": spec.exclude_weekends,
    }
    payload.update(parts)
    return json.dumps(payload, sort_keys=True, ensure_ascii=False, default=_plain)


def _plain(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return value


def _monotonic() -> float:
    return time.monotonic()


krr_dashboard_cache = DashboardCache(ttl_seconds=6 * 60 * 60)
task_dashboard_cache = DashboardCache(ttl_seconds=120)
sheets_dashboard_cache = DashboardCache(ttl_seconds=120)
