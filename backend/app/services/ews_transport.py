import logging
import ssl

import requests.adapters
from exchangelib.protocol import BaseProtocol
from urllib3.util import Retry
from urllib3.util.ssl_ import create_urllib3_context

logger = logging.getLogger(__name__)

_configured = False


class _EwsHttpAdapter(requests.adapters.HTTPAdapter):
    """HTTP adapter tuned for flaky corporate Exchange endpoints."""

    def __init__(self, *args, **kwargs) -> None:
        kwargs.setdefault(
            "max_retries",
            Retry(total=0, connect=0, read=0, redirect=0, status=0),
        )
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

    BaseProtocol.HTTP_ADAPTER_CLS = _EwsHttpAdapter
    _configured = True
    logger.debug("Configured exchangelib HTTP transport for EWS")
