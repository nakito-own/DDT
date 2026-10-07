"""NTLM transport for OWA JSON calls built by the frontend.

owa.mos.ru does not send CORS headers, and service.svc authenticates with
NTLM plus an X-OWA-CANARY cookie. The browser cannot do either, so this
module only attaches the stored credentials and forwards the JSON payload
the client already formed. It does not interpret mailbox operations.
"""

import json
import logging
import re
from dataclasses import dataclass
from threading import Lock
from urllib.parse import quote

import requests

from app.config import settings
from app.services.session_service import SessionContext

logger = logging.getLogger(__name__)

_ALLOWED_ACTIONS = frozenset(
    {
        "ApplyConversationAction",
        "CreateItem",
        "EndSearchSession",
        "ExecuteSearch",
        "FindConversation",
        "FindFolder",
        "FindItem",
        "FindPeople",
        "GetAttachment",
        "GetCalendarFolderConfiguration",
        "GetCalendarFolders",
        "GetCalendarView",
        "GetConversationItems",
        "GetFolder",
        "GetItem",
        "GetSearchSuggestions",
        "GetUserAvailabilityInternal",
        "MoveItem",
        "StartSearchSession",
        "UpdateItem",
    }
)

_AUTH_FAILURE_STATUSES = {401, 440}


class OwaTransportError(Exception):
    pass


@dataclass
class _OwaSession:
    http: requests.Session
    canary: str | None


class OwaTransport:
    def __init__(self) -> None:
        self._guard = Lock()
        self._sessions: dict[str, _OwaSession] = {}
        self._locks: dict[str, Lock] = {}

    def drop_session(self, token_hash: str) -> None:
        with self._guard:
            session = self._sessions.pop(token_hash, None)
            self._locks.pop(token_hash, None)
        if session is not None:
            session.http.close()

    def forward_json(
        self, context: SessionContext, action: str, body: bytes
    ) -> tuple[int, str, bytes]:
        if action not in _ALLOWED_ACTIONS:
            raise OwaTransportError(f"Unsupported OWA action: {action}")

        payload = body.strip() or b"{}"
        lock = self._lock_for(context.token_hash)
        with lock:
            session = self._ensure_session(context)
            response = self._post(session, action, payload)
            if response.status_code in _AUTH_FAILURE_STATUSES:
                self._discard(context.token_hash)
                session = self._ensure_session(context)
                response = self._post(session, action, payload)
            return _normalize(response)

    def _lock_for(self, token_hash: str) -> Lock:
        with self._guard:
            lock = self._locks.get(token_hash)
            if lock is None:
                lock = Lock()
                self._locks[token_hash] = lock
            return lock

    def _discard(self, token_hash: str) -> None:
        with self._guard:
            session = self._sessions.pop(token_hash, None)
        if session is not None:
            session.http.close()

    def _ensure_session(self, context: SessionContext) -> _OwaSession:
        with self._guard:
            cached = self._sessions.get(context.token_hash)
        if cached is not None:
            return cached

        http = requests.Session()
        http.headers["User-Agent"] = (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        )
        http.headers["X-AnchorMailbox"] = context.email
        try:
            signed_in = _forms_login(http, context.username, context.password)
            if not _owa_signed_in(http, signed_in) and context.email != context.username:
                signed_in = _forms_login(http, context.email, context.password)
        except requests.RequestException as exc:
            http.close()
            raise OwaTransportError(
                "Не удалось открыть сессию OWA. Проверьте VPN и повторите вход."
            ) from exc

        if not _owa_signed_in(http, signed_in):
            logger.warning(
                "OWA form login failed status=%s cookies=%s markers=%s",
                signed_in.status_code,
                sorted(http.cookies.keys()),
                _owa_markers(signed_in.text or ""),
            )
            http.close()
            raise OwaTransportError(
                "OWA не принял учетные данные. Войдите снова."
            )

        canary = _canary_from(signed_in) or http.cookies.get("X-OWA-CANARY")
        if not canary:
            try:
                home = http.get(
                    f"https://{settings.ews_server}/owa/",
                    timeout=_owa_timeout(),
                    allow_redirects=True,
                )
            except requests.RequestException as exc:
                http.close()
                raise OwaTransportError(
                    "Не удалось открыть сессию OWA. Проверьте VPN и повторите вход."
                ) from exc
            canary = _canary_from(home) or http.cookies.get("X-OWA-CANARY")
        if not canary:
            logger.warning(
                "OWA login succeeded without canary cookies=%s",
                sorted(http.cookies.keys()),
            )

        session = _OwaSession(http=http, canary=canary)
        with self._guard:
            self._sessions[context.token_hash] = session
        return session

    def _post(self, session: _OwaSession, action: str, payload: bytes) -> requests.Response:
        headers = {
            "Content-Type": "application/json; charset=UTF-8",
            "Action": action,
            "X-OWA-ActionName": action,
            "X-Requested-With": "XMLHttpRequest",
            # Official OWA sends the JSON in this header and an empty body.
            "X-OWA-UrlPostData": quote(payload.decode("utf-8"), safe=""),
        }
        if session.canary:
            headers["X-OWA-CANARY"] = session.canary
        timeout = (
            settings.ews_connect_timeout_seconds,
            settings.ews_read_timeout_seconds,
        )
        try:
            # The OWA client puts the JSON in X-OWA-UrlPostData and leaves the body empty.
            return session.http.post(
                f"https://{settings.ews_server}/owa/service.svc",
                params={"action": action},
                data=b"",
                headers=headers,
                timeout=timeout,
            )
        except requests.RequestException as exc:
            logger.exception("OWA post %s failed", action)
            raise OwaTransportError(
                "OWA не ответил. Проверьте VPN и повторите запрос."
            ) from exc


def _normalize(response: requests.Response) -> tuple[int, str, bytes]:
    content_type = response.headers.get("Content-Type", "application/json")
    if response.status_code == 200:
        body = response.content or b"{}"
        return 200, content_type, body
    if response.status_code in _AUTH_FAILURE_STATUSES:
        logger.warning(
            "OWA rejected the call with HTTP %s markers=%s",
            response.status_code,
            _owa_markers(response.text or ""),
        )
        return (
            502,
            "application/json",
            _json_bytes("OWA не принял сессию. Войдите снова."),
        )
    detail = "OWA вернул ошибку"
    text = (response.text or "").strip()
    if text and not text.startswith("<"):
        detail = text[:300]
    logger.warning(
        "OWA action failed with HTTP %s body=%s",
        response.status_code,
        (response.text or "")[:300],
    )
    return 502, "application/json", _json_bytes(detail)


def _owa_timeout() -> tuple[float, float]:
    return (
        settings.ews_connect_timeout_seconds,
        settings.ews_read_timeout_seconds,
    )


def _forms_login(
    http: requests.Session, username: str, password: str
) -> requests.Response:
    host = settings.ews_server
    timeout = _owa_timeout()
    http.get(
        f"https://{host}/owa/auth/logon.aspx",
        params={"replaceCurrent": "1", "url": f"https://{host}/owa/"},
        timeout=timeout,
        allow_redirects=True,
    )
    return http.post(
        f"https://{host}/owa/auth.owa",
        data={
            "destination": f"https://{host}/owa/",
            "flags": "4",
            "forcedownlevel": "0",
            "username": username,
            "password": password,
            "passwordText": "",
            "isUtf8": "1",
        },
        timeout=timeout,
        allow_redirects=True,
    )


def _owa_signed_in(http: requests.Session, response: requests.Response) -> bool:
    names = {name.lower() for name in http.cookies.keys()}
    if "x-owa-canary" in names or "cadata" in names or "x-backendcookie" in names:
        return True
    url = (response.url or "").lower()
    return "logon.aspx" not in url and response.status_code < 400


def _canary_from(response: requests.Response) -> str | None:
    cookie = response.cookies.get("X-OWA-CANARY")
    if cookie:
        return cookie
    header = response.headers.get("X-OWA-CANARY")
    if header:
        return header
    text = response.text or ""
    for pattern in (
        r'X-OWA-CANARY"\s*:\s*"([^"]+)"',
        r"X-OWA-CANARY'\s*:\s*'([^']+)'",
        r'name="canary"\s+value="([^"]+)"',
        r'id="hdnCanary"[^>]*value="([^"]+)"',
        r'"canary"\s*:\s*"([^"]+)"',
        r"canary\s*[:=]\s*'([^']+)'",
    ):
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match and match.group(1).strip():
            return match.group(1).strip()
    return None


def _owa_markers(text: str) -> list[str]:
    lowered = text.lower()
    markers = [
        "canary",
        "logon",
        "auth.owa",
        "sign in",
        "x-owa",
        "owaerror",
        "service.svc",
    ]
    return [marker for marker in markers if marker in lowered]


def _json_bytes(detail: str) -> bytes:
    return json.dumps({"detail": detail}, ensure_ascii=False).encode("utf-8")


owa_transport = OwaTransport()
