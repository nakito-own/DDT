import asyncio
import logging
import threading
import time
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from typing import TypeVar

from app.config import settings
from app.services.session_service import SessionContext, session_service

logger = logging.getLogger(__name__)

T = TypeVar("T")

_executor: ThreadPoolExecutor | None = None
_gate: threading.Semaphore | None = None


class EwsOverloadedError(Exception):
    """Too many concurrent blocking EWS calls; login/API would hang in queue."""


def _get_executor() -> ThreadPoolExecutor:
    global _executor
    if _executor is None:
        workers = max(2, settings.ews_thread_pool_size)
        _executor = ThreadPoolExecutor(
            max_workers=workers,
            thread_name_prefix="ews-op",
        )
        logger.info("EWS thread pool started with %s workers", workers)
    return _executor


def _get_gate() -> threading.Semaphore:
    global _gate
    if _gate is None:
        slots = max(1, settings.ews_max_concurrent_operations)
        _gate = threading.Semaphore(slots)
        logger.info("EWS concurrency gate: %s slots", slots)
    return _gate


def _run_gated(func: Callable[..., T], /, *args, **kwargs) -> T:
    gate = _get_gate()
    wait_started = time.monotonic()
    acquired = gate.acquire(timeout=settings.ews_read_timeout_seconds)
    if not acquired:
        raise EwsOverloadedError(
            "Exchange operations queue is saturated; retry in a moment"
        )
    waited = time.monotonic() - wait_started
    if waited >= 1.0:
        logger.warning(
            "Waited %.1fs for EWS slot before %s",
            waited,
            getattr(func, "__name__", repr(func)),
        )
    try:
        return func(*args, **kwargs)
    finally:
        gate.release()


async def run_blocking(func: Callable[..., T], /, *args, **kwargs) -> T:
    """Run a blocking call (DB + EWS) off the event loop on the EWS worker pool."""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(
        _get_executor(),
        lambda: _run_gated(func, *args, **kwargs),
    )


async def run_ews(
    context: SessionContext,
    operation: Callable[..., T],
    /,
    *args,
    **kwargs,
) -> T:
    """Run a blocking exchangelib call off the asyncio event loop."""

    def _run() -> T:
        return session_service.run_with_account(
            context,
            lambda account: operation(account, *args, **kwargs),
        )

    return await run_blocking(_run)


def shutdown_ews_executor() -> None:
    global _executor
    if _executor is None:
        return
    _executor.shutdown(wait=False, cancel_futures=True)
    _executor = None
    logger.info("EWS thread pool shut down")
