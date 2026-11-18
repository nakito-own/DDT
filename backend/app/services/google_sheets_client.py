import json
import logging
from pathlib import Path

import httplib2
from google.auth.exceptions import TransportError
from google.oauth2 import service_account
from google_auth_httplib2 import AuthorizedHttp
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from app.config import settings

logger = logging.getLogger(__name__)

_SCOPES = ("https://www.googleapis.com/auth/spreadsheets.readonly",)


class GoogleSheetsConfigError(RuntimeError):
    pass


class GoogleSheetsAccessError(RuntimeError):
    def __init__(self, message: str, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


def _resolve_credentials_path(path: str) -> Path:
    candidate = Path(path).expanduser()
    search = [candidate]
    if not candidate.is_absolute():
        cwd = Path.cwd()
        search.extend((cwd / candidate, cwd.parent / candidate))
    for item in search:
        if item.is_file():
            return item
    raise GoogleSheetsConfigError(
        f"Google Sheets credentials file not found: {path}"
    )


def _load_credentials() -> service_account.Credentials:
    raw_json = settings.google_sheets_credentials_json.strip()
    if raw_json:
        try:
            info = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            raise GoogleSheetsConfigError(
                "GOOGLE_SHEETS_CREDENTIALS_JSON is not valid JSON"
            ) from exc
        return service_account.Credentials.from_service_account_info(
            info, scopes=_SCOPES
        )

    path = settings.google_sheets_credentials_path.strip()
    if path:
        return service_account.Credentials.from_service_account_file(
            str(_resolve_credentials_path(path)),
            scopes=_SCOPES,
        )

    raise GoogleSheetsConfigError(
        "Set GOOGLE_SHEETS_CREDENTIALS_PATH or GOOGLE_SHEETS_CREDENTIALS_JSON"
    )


class GoogleSheetsClient:
    def __init__(self) -> None:
        self._credentials: service_account.Credentials | None = None

    def _authorized_http(self) -> AuthorizedHttp:
        if self._credentials is None:
            self._credentials = _load_credentials()
        timeout = max(5.0, settings.google_sheets_timeout_seconds)
        # One HTTP client per request: httplib2.Http is not safe to share across calls.
        return AuthorizedHttp(
            self._credentials,
            http=httplib2.Http(timeout=timeout),
        )

    def fetch_sheet_values(self, spreadsheet_id: str, sheet_name: str) -> list[list[object]]:
        try:
            # static_discovery skips the discovery-document download, which
            # otherwise runs on every request and surfaces as TimeoutError.
            service = build(
                "sheets",
                "v4",
                http=self._authorized_http(),
                cache_discovery=False,
                static_discovery=True,
            )
            result = (
                service.spreadsheets()
                .values()
                .get(
                    spreadsheetId=spreadsheet_id,
                    range=f"'{sheet_name}'",
                    majorDimension="ROWS",
                    valueRenderOption="FORMATTED_VALUE",
                    dateTimeRenderOption="FORMATTED_STRING",
                )
                .execute(num_retries=1)
            )
        except HttpError as exc:
            try:
                status = int(getattr(exc.resp, "status", 0) or 0)
            except (TypeError, ValueError):
                status = 0
            if status in {401, 403}:
                raise GoogleSheetsAccessError(
                    "Service account cannot read the spreadsheet. "
                    "Share the sheet with the account client_email as Viewer.",
                    status_code=status,
                ) from exc
            if status == 404:
                raise GoogleSheetsAccessError(
                    f"Spreadsheet or sheet '{sheet_name}' was not found.",
                    status_code=404,
                ) from exc
            raise GoogleSheetsAccessError(
                "Google Sheets API request failed",
                status_code=status or 502,
            ) from exc
        except TimeoutError as exc:
            logger.warning("Google Sheets request timed out: %s", exc)
            raise GoogleSheetsAccessError(
                "Не удалось получить таблицу аналитики: истекло время ожидания Google Sheets.",
                status_code=504,
            ) from exc
        except (OSError, httplib2.HttpLib2Error, TransportError) as exc:
            logger.warning("Google Sheets request failed: %s", exc)
            raise GoogleSheetsAccessError(
                "Не удалось получить таблицу аналитики из Google Sheets.",
                status_code=502,
            ) from exc

        return result.get("values", [])


google_sheets_client = GoogleSheetsClient()
