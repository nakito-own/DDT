"""Клиент авторизации и постраничной выгрузки набора DTW."""

import base64
import json
import logging
import time
from typing import Any

import requests

from app.config import settings
from app.services.krr_records import dtw_attributes

logger = logging.getLogger(__name__)


class DtwError(RuntimeError):
    def __init__(self, message: str, status_code: int = 502) -> None:
        self.status_code = status_code
        super().__init__(message)


class DtwNotConfiguredError(DtwError):
    def __init__(self) -> None:
        super().__init__(
            "Укажите DTW_LOGIN и DTW_PASSWORD для загрузки набора КРР.",
            status_code=503,
        )


class DtwClient:
    def __init__(self) -> None:
        base = settings.dtw_base_url.rstrip("/")
        dataset_id = settings.dtw_dataset_id
        self._login_url = f"{base}/app/auth/login"
        self._data_url = (
            f"{base}/app/api/data-output/datasets/"
            f"GetDataWithRequest/{dataset_id}"
        )
        self._page_size = max(1, settings.dtw_page_size)
        self._offset_param = settings.dtw_offset_param.strip() or "offset"
        self._limit_param = settings.dtw_limit_param.strip() or "limit"
        timeout = max(5.0, settings.dtw_timeout_seconds)
        self._timeout = (15.0, timeout)
        self._session = requests.Session()
        self._session.headers["User-Agent"] = "DDT-KRR-Sync/1.0"
        self._token = ""
        self._token_deadline = 0.0

    def fetch_page(self, *, offset: int) -> dict[str, Any]:
        response: requests.Response | None = None
        for attempt in range(3):
            response = self._get_page(self._access_token(), offset)
            if response.status_code == 401:
                self._token = ""
                continue
            if response.status_code == 504 and attempt < 2:
                logger.warning(
                    "DTW page offset=%s timed out, retry %s",
                    offset,
                    attempt + 1,
                )
                time.sleep(2)
                continue
            break
        assert response is not None
        return self._page_payload(response)

    def _access_token(self) -> str:
        if self._token and time.monotonic() < self._token_deadline:
            return self._token
        login = settings.dtw_login.strip()
        password = settings.dtw_password
        if not login or not password:
            raise DtwNotConfiguredError()

        try:
            response = self._session.post(
                self._login_url,
                files={
                    "login": (None, login),
                    "password": (None, password),
                },
                timeout=self._timeout,
            )
        except requests.Timeout as exc:
            raise DtwError("Истекло время ожидания авторизации DTW.", 504) from exc
        except requests.RequestException as exc:
            raise DtwError("Не удалось выполнить авторизацию в DTW.", 502) from exc

        payload = self._json_object(response, "авторизации DTW")
        token = _find_token(payload)
        if not token:
            raise DtwError(
                "Ответ авторизации DTW не содержит accessToken.",
                502,
            )
        self._token = token
        self._token_deadline = _token_deadline(token, payload)
        logger.info("DTW access token received")
        return token

    def _page_url(self, offset: int) -> str:
        # requests encodes a params dict, and DTW rejects %2C in attributes.
        # The comma and the following space must stay readable.
        attributes = dtw_attributes()
        return (
            f"{self._data_url}?attributes={attributes}"
            f"&{self._offset_param}={offset}"
            f"&{self._limit_param}={self._page_size}"
        )

    def _get_page(self, token: str, offset: int) -> requests.Response:
        try:
            return self._session.get(
                self._page_url(offset),
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                },
                timeout=self._timeout,
            )
        except requests.Timeout as exc:
            raise DtwError("Истекло время ожидания ответа DTW.", 504) from exc
        except requests.RequestException as exc:
            raise DtwError("Не удалось получить страницу набора DTW.", 502) from exc

    def _page_payload(self, response: requests.Response) -> dict[str, Any]:
        payload = self._json_object(response, "набора DTW")
        rows = payload.get("data")
        if not isinstance(rows, list):
            raise DtwError("Ответ набора DTW не содержит список data.", 502)
        return payload

    @staticmethod
    def _json_object(response: requests.Response, what: str) -> dict[str, Any]:
        if response.status_code == 401:
            raise DtwError("DTW отклонил учётные данные.", 502)
        if response.status_code >= 400:
            detail = " ".join(response.text.split())[:240]
            raise DtwError(
                f"DTW вернул ошибку {response.status_code} при запросе {what}. {detail}".strip(),
                502 if response.status_code < 500 else 504,
            )
        try:
            payload = response.json()
        except ValueError as exc:
            raise DtwError(f"Ответ {what} не является JSON.", 502) from exc
        if not isinstance(payload, dict):
            raise DtwError(f"Ответ {what} имеет неожиданный формат.", 502)
        return payload


def _find_token(payload: dict[str, Any]) -> str:
    for key in ("accessToken", "access_token", "token"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    nested = payload.get("data")
    if isinstance(nested, dict):
        return _find_token(nested)
    return ""


def _token_deadline(token: str, payload: dict[str, Any]) -> float:
    expires_in = payload.get("expiresIn", payload.get("expires_in"))
    nested = payload.get("data")
    if not isinstance(expires_in, (int, float)) and isinstance(nested, dict):
        expires_in = nested.get("expiresIn", nested.get("expires_in"))
    if isinstance(expires_in, (int, float)) and expires_in > 0:
        return time.monotonic() + max(30.0, float(expires_in) - 60.0)
    exp = _jwt_exp(token)
    if exp is not None:
        return time.monotonic() + max(30.0, exp - time.time() - 60.0)
    return time.monotonic() + 20 * 60


def _jwt_exp(token: str) -> float | None:
    parts = token.split(".")
    if len(parts) < 2:
        return None
    padding = "=" * (-len(parts[1]) % 4)
    try:
        raw = base64.urlsafe_b64decode(parts[1] + padding)
        payload = json.loads(raw)
    except (ValueError, json.JSONDecodeError):
        return None
    exp = payload.get("exp") if isinstance(payload, dict) else None
    if isinstance(exp, (int, float)):
        return float(exp)
    return None
