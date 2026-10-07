import logging
import time
from dataclasses import dataclass

from exchangelib import DELEGATE, Account, Configuration, Credentials
from exchangelib.errors import (
    ErrorAccessDenied,
    ErrorInvalidUserPrincipalName,
    TransportError,
    UnauthorizedError,
)

from app.config import settings
from app.services.ews_transport import configure_ews_transport

logger = logging.getLogger(__name__)

configure_ews_transport()


class EwsConnectionError(Exception):
    pass


class EwsBusyError(EwsConnectionError):
    """Exchange throttled this user; retrying before retry_after only extends it."""

    def __init__(self, retry_after: float) -> None:
        super().__init__(
            "Exchange временно ограничил запросы, повторите через "
            f"{max(1, round(retry_after))} с"
        )
        self.retry_after = retry_after


def server_busy_cause(exc: BaseException | None):
    from exchangelib.errors import ErrorServerBusy

    seen: set[int] = set()
    while exc is not None and id(exc) not in seen:
        if isinstance(exc, ErrorServerBusy):
            return exc
        seen.add(id(exc))
        exc = exc.__cause__ or exc.__context__
    return None


class EwsAuthError(Exception):
    pass


_EWS_AUTH_ERRORS = (
    UnauthorizedError,
    ErrorAccessDenied,
    ErrorInvalidUserPrincipalName,
)


@dataclass
class ExchangeUserProfile:
    email: str
    display_name: str
    job_title: str | None = None
    department: str | None = None
    phone: str | None = None
    office_location: str | None = None


class EwsService:
    """Mailbox login and profile lookup.

    Mail, calendar, and contacts go through the OWA JSON API from the
    frontend. This service only opens the account used to prove credentials
    and to keep notification streaming alive.
    """

    def _configuration(self, username: str, password: str) -> Configuration:
        credentials = Credentials(username=username, password=password)
        auth_type = settings.ews_auth_type.strip() or None
        endpoint = settings.ews_service_endpoint.strip() or None
        return Configuration(
            server=settings.ews_server,
            credentials=credentials,
            auth_type=auth_type,
            service_endpoint=endpoint,
        )

    def create_account(self, username: str, password: str, email: str) -> Account:
        return Account(
            primary_smtp_address=email,
            config=self._configuration(username, password),
            autodiscover=False,
            access_type=DELEGATE,
        )

    @staticmethod
    def close_account(account: Account | None) -> None:
        # exchangelib caches one Protocol (and its session pool) per
        # endpoint+credentials and shares it between every Account with the same
        # login. Closing it here would drain sessions still used by other
        # threads and corrupt the pool size counter, after which get_session()
        # blocks forever. Broken sessions are retired by exchangelib itself.
        return

    def connect_account(self, username: str, password: str, email: str) -> Account:
        max_attempts = max(1, settings.ews_verify_max_attempts)
        retry_delay = max(0.0, settings.ews_verify_retry_delay_seconds)
        last_transport_error: TransportError | None = None

        for attempt in range(max_attempts):
            account = self.create_account(username, password, email)
            try:
                self.verify_account(account)
                return account
            except EwsAuthError:
                self.close_account(account)
                raise
            except EwsConnectionError as exc:
                self.close_account(account)
                if server_busy_cause(exc) is not None:
                    raise
                cause = exc.__cause__
                if isinstance(cause, TransportError):
                    last_transport_error = cause
                    logger.warning(
                        "EWS transport error on connect attempt %s/%s: %s",
                        attempt + 1,
                        max_attempts,
                        cause,
                    )
                    if attempt + 1 < max_attempts:
                        time.sleep(retry_delay * (attempt + 1))
                        continue
                raise
            except Exception:
                self.close_account(account)
                raise

        if last_transport_error is not None:
            raise EwsConnectionError(
                "Failed to connect to Exchange (network or server unavailable)"
            ) from last_transport_error

        raise EwsConnectionError(
            "Failed to connect to Exchange (network or server unavailable)"
        )

    def verify_account(self, account: Account) -> None:
        try:
            _ = account.inbox.total_count
        except _EWS_AUTH_ERRORS as exc:
            raise EwsAuthError("Invalid Exchange credentials") from exc
        except TransportError as exc:
            raise EwsConnectionError(
                "Failed to connect to Exchange (network or server unavailable)"
            ) from exc
        except Exception as exc:
            raise EwsConnectionError("Failed to connect to Exchange") from exc

    def get_user_profile(self, account: Account) -> ExchangeUserProfile:
        email = str(account.primary_smtp_address)
        display_name = email.split("@")[0]
        job_title = None
        department = None
        phone = None
        office_location = None

        try:
            resolutions = account.protocol.resolve_names(
                [email],
                return_full_contact_data=True,
            )
            for mailbox, contact in resolutions:
                if mailbox and mailbox.name:
                    display_name = mailbox.name
                if contact is None:
                    continue
                if contact.display_name:
                    display_name = contact.display_name
                job_title = contact.job_title or job_title
                department = contact.department or department
                office_location = contact.office or office_location
                if contact.phone_numbers:
                    for phone_entry in contact.phone_numbers:
                        number = getattr(phone_entry, "phone_number", None)
                        if number:
                            phone = number
                            break
                break
        except Exception:
            logger.debug("Failed to resolve Exchange user profile", exc_info=True)

        return ExchangeUserProfile(
            email=email,
            display_name=display_name,
            job_title=job_title,
            department=department,
            phone=phone,
            office_location=office_location,
        )


ews_service = EwsService()
