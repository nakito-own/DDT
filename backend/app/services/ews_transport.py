import logging
import ssl

import requests.adapters
from exchangelib.protocol import BaseProtocol
from urllib3.util import Retry
from urllib3.util.ssl_ import create_urllib3_context

from app.config import settings

logger = logging.getLogger(__name__)

_configured = False


class _EwsHttpAdapter(requests.adapters.HTTPAdapter):
    """HTTP adapter tuned for flaky corporate Exchange endpoints."""

    def __init__(self, *args, pool_maxsize: int, **kwargs) -> None:
        kwargs.setdefault(
            "max_retries",
            Retry(total=0, connect=0, read=0, redirect=0, status=0),
        )
        kwargs.setdefault("pool_connections", pool_maxsize)
        kwargs.setdefault("pool_maxsize", pool_maxsize)
        super().__init__(*args, **kwargs)

    def init_poolmanager(self, *args, **kwargs):
        ctx = create_urllib3_context()
        ctx.options |= ssl.OP_NO_COMPRESSION
        kwargs["ssl_context"] = ctx
        return super().init_poolmanager(*args, **kwargs)


def configure_ews_transport() -> None:
    global _configured
    if _configured:
        return

    pool_maxsize = max(2, settings.ews_pool_maxsize)
    connect_timeout = max(1.0, settings.ews_connect_timeout_seconds)
    read_timeout = max(1.0, settings.ews_read_timeout_seconds)

    class _ConfiguredEwsHttpAdapter(_EwsHttpAdapter):
        def __init__(self, *args, **kwargs) -> None:
            # exchangelib 5.x also passes pool_maxsize; drop it so we apply settings.
            kwargs.pop("pool_maxsize", None)
            super().__init__(*args, pool_maxsize=pool_maxsize, **kwargs)

    BaseProtocol.HTTP_ADAPTER_CLS = _ConfiguredEwsHttpAdapter
    BaseProtocol.TIMEOUT = (connect_timeout, read_timeout)
    BaseProtocol.MAX_SESSIONS = pool_maxsize
    _configured = True
    logger.info(
        "Configured EWS transport (pool=%s, timeout connect=%ss read=%ss)",
        pool_maxsize,
        connect_timeout,
        read_timeout,
    )
