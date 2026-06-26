import json
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from html import unescape
from typing import Any, Literal, Literal
from zoneinfo import ZoneInfo

import pytz
from exchangelib import (
    DELEGATE,
    Account,
    CalendarItem,
    Configuration,
    Credentials,
    HTMLBody,
    Mailbox,
    Message,
)
from exchangelib.errors import ErrorItemNotFound

from app.config import settings

logger = logging.getLogger(__name__)


class EwsConnectionError(Exception):
    pass


class EwsNotFoundError(Exception):
    pass


@dataclass
class MailSummary:
    id: str
    subject: str
    sender: str | None
    datetime_received: datetime | None
    is_read: bool
    preview: str


@dataclass
class MailDetail(MailSummary):
    body: str
    body_type: Literal["text", "html"] = "text"


@dataclass
class CalendarEvent:
    id: str
    subject: str
    start: datetime | None
    end: datetime | None
    location: str | None
    organizer: str | None
    my_response_type: str | None = None
    is_meeting: bool = False
    is_response_requested: bool | None = None
    needs_response: bool = False


@dataclass
class Contact:
    id: str
    display_name: str
    emails: list[str]
    phones: list[str]


@dataclass
class ExchangeUserProfile:
    email: str
    display_name: str
    job_title: str | None = None
    department: str | None = None
    phone: str | None = None
    office_location: str | None = None


def _serialize_item_id(item_id: Any) -> str:
    if isinstance(item_id, str):
        try:
            parsed = json.loads(item_id)
            if isinstance(parsed, dict) and "id" in parsed:
                return item_id
        except json.JSONDecodeError:
            pass
        return json.dumps({"id": item_id, "changekey": None})

    item_value = getattr(item_id, "id", None)
    changekey = getattr(item_id, "changekey", None)
    if item_value is None:
        item_value = str(item_id)

    return json.dumps({"id": item_value, "changekey": changekey})


def _html_to_plain(html: str, max_len: int = 300) -> str:
    text = re.sub(
        r"<(script|style)[^>]*>.*?</\1>",
        " ",
        html,
        flags=re.DOTALL | re.IGNORECASE,
    )
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:max_len]


def _extract_body(item: Any) -> tuple[str, Literal["text", "html"]]:
    try:
        body = item.body
        if body is not None:
            if isinstance(body, HTMLBody) or getattr(body, "body_type", None) == "HTML":
                return str(body), "html"
            return str(body), "text"
        if item.text_body:
            return str(item.text_body), "text"
    except Exception:
        logger.debug("Failed to extract message body", exc_info=True)
    return "", "text"


def _message_preview(item: Any) -> str:
    try:
        if item.text_body:
            return str(item.text_body)[:300].strip()
    except Exception:
        logger.debug("Failed to build message preview", exc_info=True)
    return ""


def _get_inbox_item(account: Account, message_id: str) -> Any:
    item_id = _parse_item_id(message_id)
    try:
        if item_id["changekey"]:
            return account.inbox.get(
                id=item_id["id"],
                changekey=item_id["changekey"],
            )
        return account.inbox.get(id=item_id["id"])
    except ErrorItemNotFound as exc:
        raise EwsNotFoundError("Message not found") from exc


def _get_calendar_item(account: Account, event_id: str) -> CalendarItem:
    item_id = _parse_item_id(event_id)
    try:
        if item_id["changekey"]:
            return account.calendar.get(
                id=item_id["id"],
                changekey=item_id["changekey"],
            )
        return account.calendar.get(id=item_id["id"])
    except ErrorItemNotFound as exc:
        raise EwsNotFoundError("Calendar event not found") from exc


def _calendar_event_needs_response(item: CalendarItem) -> bool:
    if not item.is_meeting:
        return False
    response = item.my_response_type
    return response in ("NoResponseReceived", "Unknown")


def _calendar_event_from_item(item: CalendarItem) -> CalendarEvent:
    return CalendarEvent(
        id=_serialize_item_id(item.id),
        subject=item.subject or "(без темы)",
        start=_to_iso(item.start),
        end=_to_iso(item.end),
        location=item.location or None,
        organizer=_format_address(item.organizer),
        my_response_type=item.my_response_type,
        is_meeting=bool(item.is_meeting),
        is_response_requested=item.is_response_requested,
        needs_response=_calendar_event_needs_response(item),
    )


def _parse_item_id(raw_id: str) -> dict[str, str | None]:
    data = json.loads(raw_id)
    return {"id": data["id"], "changekey": data.get("changekey")}


def _format_address(value: Any) -> str | None:
    if value is None:
        return None
    email = getattr(value, "email_address", None)
    if email:
        return email
    return str(value)


def _to_ews_datetime(value: datetime | None) -> datetime:
    tz = pytz.timezone(settings.ews_timezone)
    if value is None:
        return datetime.now(tz)

    if value.tzinfo is None:
        return tz.localize(value)

    return datetime.fromtimestamp(value.timestamp(), pytz.UTC).astimezone(tz)


def _to_iso(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=ZoneInfo(settings.ews_timezone))
    return value


class EwsService:
    def create_account(self, username: str, password: str, email: str) -> Account:
        credentials = Credentials(username=username, password=password)
        config = Configuration(
            server=settings.ews_server,
            credentials=credentials,
            auth_type=None,
        )
        account = Account(
            primary_smtp_address=email,
            config=config,
            autodiscover=False,
            access_type=DELEGATE,
        )
        return account

    def verify_account(self, account: Account) -> None:
        try:
            _ = account.inbox.total_count
        except Exception as exc:
            raise EwsConnectionError("Failed to connect to Exchange") from exc

    def get_user_profile(self, account: Account) -> ExchangeUserProfile:
        email = account.primary_smtp_address
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

    def get_folder_counts(self, account: Account) -> dict[str, int]:
        return {
            "inbox": account.inbox.total_count,
            "sent": account.sent.total_count,
        }

    def list_inbox_messages(
        self, account: Account, limit: int = 50, offset: int = 0
    ) -> list[MailSummary]:
        queryset = (
            account.inbox.all()
            .only(
                "id",
                "subject",
                "sender",
                "datetime_received",
                "is_read",
                "text_body",
            )
            .order_by("-datetime_received")
        )
        items = list(queryset[offset : offset + limit])
        result: list[MailSummary] = []

        for item in items:
            try:
                result.append(
                    MailSummary(
                        id=_serialize_item_id(item.id),
                        subject=item.subject or "(без темы)",
                        sender=_format_address(item.sender),
                        datetime_received=_to_iso(item.datetime_received),
                        is_read=bool(item.is_read),
                        preview=_message_preview(item),
                    )
                )
            except Exception:
                logger.warning(
                    "Skipping inbox message due to serialization error",
                    exc_info=True,
                )

        return result

    def get_message(
        self, account: Account, message_id: str, *, mark_read: bool = False
    ) -> MailDetail:
        item = _get_inbox_item(account, message_id)

        if mark_read and not item.is_read:
            item.is_read = True
            item.save(update_fields=["is_read"])

        body, body_type = _extract_body(item)
        preview = _message_preview(item) or (
            _html_to_plain(body) if body_type == "html" else body[:300].strip()
        )

        return MailDetail(
            id=_serialize_item_id(item.id),
            subject=item.subject or "(без темы)",
            sender=_format_address(item.sender),
            datetime_received=_to_iso(item.datetime_received),
            is_read=bool(item.is_read),
            preview=preview,
            body=body,
            body_type=body_type,
        )

    def mark_message_read(self, account: Account, message_id: str) -> MailSummary:
        item = _get_inbox_item(account, message_id)

        if not item.is_read:
            item.is_read = True
            item.save(update_fields=["is_read"])

        return MailSummary(
            id=_serialize_item_id(item.id),
            subject=item.subject or "(без темы)",
            sender=_format_address(item.sender),
            datetime_received=_to_iso(item.datetime_received),
            is_read=True,
            preview=_message_preview(item),
        )

    def send_message(
        self,
        account: Account,
        to: list[str],
        subject: str,
        body: str,
        cc: list[str] | None = None,
    ) -> None:
        message = Message(
            account=account,
            subject=subject,
            body=body,
            to_recipients=[Mailbox(email_address=email) for email in to],
            cc_recipients=[
                Mailbox(email_address=email) for email in (cc or [])
            ],
        )
        try:
            message.send()
        except Exception as exc:
            raise EwsConnectionError("Failed to send message") from exc

    def list_calendar_events(
        self,
        account: Account,
        start: datetime | None = None,
        end: datetime | None = None,
    ) -> list[CalendarEvent]:
        start = _to_ews_datetime(start)
        end = _to_ews_datetime(end) if end is not None else start + timedelta(days=7)

        events: list[CalendarEvent] = []
        for item in account.calendar.view(start=start, end=end):
            if not isinstance(item, CalendarItem):
                continue

            events.append(_calendar_event_from_item(item))

        return events

    def create_calendar_event(
        self,
        account: Account,
        subject: str,
        start: datetime,
        end: datetime,
        location: str | None = None,
        body: str | None = None,
    ) -> CalendarEvent:
        start_dt = _to_ews_datetime(start)
        end_dt = _to_ews_datetime(end)

        if end_dt <= start_dt:
            raise ValueError("Event end must be after start")

        item = CalendarItem(
            account=account,
            folder=account.calendar,
            subject=subject,
            start=start_dt,
            end=end_dt,
            location=location or "",
            body=body or "",
        )

        try:
            item.save()
        except Exception as exc:
            raise EwsConnectionError("Failed to create calendar event") from exc

        return _calendar_event_from_item(item)

    def respond_to_calendar_event(
        self,
        account: Account,
        event_id: str,
        response: Literal["accept", "decline", "tentative"],
    ) -> CalendarEvent:
        item = _get_calendar_item(account, event_id)

        if not isinstance(item, CalendarItem):
            raise ValueError("Item is not a calendar event")

        try:
            if response == "accept":
                item.accept()
            elif response == "decline":
                item.decline()
            else:
                item.tentatively_accept()
        except Exception as exc:
            raise EwsConnectionError("Failed to respond to calendar event") from exc

        try:
            item.refresh()
        except Exception:
            logger.debug("Failed to refresh calendar event after response", exc_info=True)

        return _calendar_event_from_item(item)

    def list_contacts(
        self, account: Account, limit: int = 100, search: str = ""
    ) -> list[Contact]:
        contact_folders = [
            account.contacts,
            account.root / "AllContacts",
            account.root / "RelevantContacts",
        ]

        seen_ids: set[str] = set()
        contacts: list[Contact] = []
        search_lower = search.strip().lower()

        for folder in contact_folders:
            try:
                for contact in folder.all():
                    contact_id = _serialize_item_id(contact.id)
                    if contact_id in seen_ids:
                        continue
                    seen_ids.add(contact_id)

                    display_name = contact.display_name or "Без имени"
                    emails = [
                        addr.email
                        for addr in (contact.email_addresses or [])
                        if getattr(addr, "email", None)
                    ]
                    phones = [
                        phone.phone_number
                        for phone in (contact.phone_numbers or [])
                        if getattr(phone, "phone_number", None)
                    ]

                    if search_lower:
                        haystack = " ".join([display_name, *emails, *phones]).lower()
                        if search_lower not in haystack:
                            continue

                    contacts.append(
                        Contact(
                            id=contact_id,
                            display_name=display_name,
                            emails=emails,
                            phones=phones,
                        )
                    )

                    if len(contacts) >= limit:
                        return contacts
            except Exception:
                logger.debug("Skipping unavailable contact folder", exc_info=True)

        return contacts


ews_service = EwsService()
