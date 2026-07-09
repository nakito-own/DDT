import json
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from html import unescape
from typing import Any, Callable, Literal
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
    Q,
)
from exchangelib.errors import ErrorItemNotFound
from exchangelib.extended_properties import ExtendedProperty

from app.config import settings

logger = logging.getLogger(__name__)


class EwsConnectionError(Exception):
    pass


class EwsNotFoundError(Exception):
    pass


@dataclass
class MailAttachment:
    id: str
    name: str
    size: int
    content_type: str


@dataclass
class MailSummary:
    id: str
    folder_id: str
    subject: str
    sender: str | None
    datetime_received: datetime | None
    is_read: bool
    preview: str
    has_attachments: bool = False


@dataclass
class MailDetail(MailSummary):
    body: str = ""
    body_type: Literal["text", "html"] = "text"
    attachments: list[MailAttachment] = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        if self.attachments is None:
            self.attachments = []


@dataclass
class MailFolder:
    id: str
    name: str
    total_count: int
    unread_count: int
    children: list["MailFolder"]


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


def _serialize_folder_id(folder_id: Any) -> str:
    value = getattr(folder_id, "id", None)
    if value is None:
        value = str(folder_id)
    return json.dumps({"id": value})


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


def _message_sender(item: Any) -> str | None:
    sender = _format_address(getattr(item, "sender", None))
    if sender:
        return sender
    return _format_address(getattr(item, "author", None))


def _mail_summary_from_item(item: Any, *, folder_id: str) -> MailSummary:
    return MailSummary(
        id=_serialize_item_id(item.id),
        folder_id=folder_id,
        subject=item.subject or "(без темы)",
        sender=_message_sender(item),
        datetime_received=_to_iso(item.datetime_received),
        is_read=bool(item.is_read),
        preview=_message_preview(item),
        has_attachments=bool(getattr(item, "has_attachments", False)),
    )


def _attachment_id_str(att: Any) -> str | None:
    att_id = getattr(att, "attachment_id", None)
    if att_id is not None:
        raw_id = getattr(att_id, "id", None)
        if raw_id:
            return str(raw_id)
        att_id_str = str(att_id).strip()
        if att_id_str:
            return att_id_str
    raw = getattr(att, "id", None)
    if raw:
        return str(raw)
    return None


def _load_raw_attachments(account: Account, item: Any) -> list[Any]:
    attachments = list(item.attachments or [])
    if attachments or not getattr(item, "has_attachments", False):
        return attachments

    try:
        from exchangelib.properties import ALL_PROPERTIES
        from exchangelib.services import GetItem

        for loaded in GetItem(account=account).get(
            items=[item],
            additional_fields=None,
            shape=ALL_PROPERTIES,
        ):
            return list(loaded.attachments or [])
    except Exception:
        logger.debug("Failed to load attachments via GetItem", exc_info=True)
    return attachments


def _attachments_from_item(account: Account, item: Any) -> list[MailAttachment]:
    result: list[MailAttachment] = []
    try:
        for att in _load_raw_attachments(account, item):
            att_id = _attachment_id_str(att)
            if not att_id:
                continue
            result.append(
                MailAttachment(
                    id=att_id,
                    name=str(getattr(att, "name", None) or "attachment"),
                    size=int(getattr(att, "size", 0) or 0),
                    content_type=str(
                        getattr(att, "content_type", None) or "application/octet-stream"
                    ),
                )
            )
    except Exception:
        logger.debug("Failed to extract message attachments", exc_info=True)
    return result


def _get_archive_folder(account: Account) -> Any:
    archive_names = frozenset({"archive", "архив", "archives"})
    try:
        for folder in account.msg_folder_root.children:
            if (getattr(folder, "name", "") or "").lower() in archive_names:
                return folder
    except Exception:
        pass
    for attr in ("archive", "archive_root", "archive_inbox"):
        try:
            folder = getattr(account, attr, None)
            if folder is not None:
                return folder
        except Exception:
            pass
    raise EwsNotFoundError("Archive folder not found")


def _get_folder_item(folder: Any, message_id: str) -> Any:
    item_id = _parse_item_id(message_id)
    try:
        if item_id["changekey"]:
            return folder.get(
                id=item_id["id"],
                changekey=item_id["changekey"],
            )
        return folder.get(id=item_id["id"])
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
    normalized = raw_id.strip()
    for suffix in ("/attachment", "/read"):
        if normalized.endswith(suffix):
            normalized = normalized[: -len(suffix)].strip()
            break

    try:
        data = json.loads(normalized)
    except json.JSONDecodeError:
        data, _ = json.JSONDecoder().raw_decode(normalized)

    if not isinstance(data, dict) or "id" not in data:
        raise EwsNotFoundError("Invalid message id")

    changekey = data.get("changekey")
    return {"id": str(data["id"]), "changekey": changekey}


def _parse_folder_id(raw_id: str) -> str:
    normalized = raw_id.strip()
    try:
        data = json.loads(normalized)
    except json.JSONDecodeError:
        try:
            data, _ = json.JSONDecoder().raw_decode(normalized)
        except json.JSONDecodeError:
            return normalized

    if isinstance(data, dict) and "id" in data:
        return str(data["id"])
    return normalized


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


MailFilter = Literal["all", "to_me", "flagged", "mentions"]
MailSort = Literal[
    "date_asc",
    "date_desc",
    "from",
    "to",
    "subject",
    "attachments",
    "importance",
]

_INBOX_ONLY_FIELDS = (
    "id",
    "subject",
    "sender",
    "author",
    "display_to",
    "datetime_received",
    "is_read",
    "text_body",
    "has_attachments",
    "importance",
    "to_recipients",
    "cc_recipients",
)

_SORT_ORDER: dict[MailSort, str] = {
    "date_asc": "datetime_received",
    "date_desc": "-datetime_received",
    "from": "author",
    "to": "display_to",
    "subject": "subject",
    "attachments": "-has_attachments",
    "importance": "-importance",
}


class FollowupFlag(ExtendedProperty):
    property_tag = 0x1090
    property_type = "Integer"


Message.register("followup_flag", FollowupFlag)


def _mailbox_email(value: Any) -> str | None:
    if value is None:
        return None
    email = getattr(value, "email_address", None)
    if email:
        return str(email).lower()
    return str(value).lower()


def _is_to_me(item: Any, user_email: str) -> bool:
    email = user_email.lower()
    to_recipients = item.to_recipients or []
    return any(_mailbox_email(recipient) == email for recipient in to_recipients)


def _is_flagged(item: Any) -> bool:
    flag_value = getattr(item, "followup_flag", None)
    return flag_value == 2


def _is_mention(item: Any, user_email: str) -> bool:
    local_part = user_email.split("@", 1)[0].lower()
    haystack = " ".join(
        part
        for part in (
            item.subject or "",
            getattr(item, "text_body", None) or "",
        )
        if part
    ).lower()

    if f"@{local_part}" in haystack:
        return True

    return f"@{user_email.lower()}" in haystack


def _message_predicate(
    mail_filter: MailFilter,
    user_email: str | None,
) -> Callable[[Any], bool] | None:
    if mail_filter in ("all", "flagged"):
        return None
    if mail_filter == "to_me":
        if not user_email:
            return lambda _item: False
        email = user_email.lower()
        return lambda item: _is_to_me(item, email)
    if mail_filter == "flagged":
        return _is_flagged
    if mail_filter == "mentions":
        if not user_email:
            return lambda _item: False
        email = user_email.lower()
        return lambda item: _is_mention(item, email)
    return None


def _collect_inbox_page(
    queryset: Any,
    *,
    limit: int,
    offset: int,
    predicate: Callable[[Any], bool] | None,
) -> list[Any]:
    if predicate is None:
        return list(queryset[offset : offset + limit])

    matched: list[Any] = []
    skipped = 0
    for item in queryset:
        if not predicate(item):
            continue
        if skipped < offset:
            skipped += 1
            continue
        matched.append(item)
        if len(matched) >= limit:
            break
    return matched


def _item_datetime_value(item: Any) -> float:
    value = getattr(item, "datetime_received", None) or getattr(
        item, "datetime_created", None
    )
    if value is None:
        return 0.0
    try:
        return float(value.timestamp())
    except Exception:
        return 0.0


def _item_importance_rank(item: Any) -> int:
    importance = str(getattr(item, "importance", "") or "").lower()
    if importance == "high":
        return 2
    if importance == "normal":
        return 1
    return 0


def _fallback_sort_items(items: list[Any], sort: MailSort) -> list[Any]:
    if sort == "date_asc":
        return sorted(items, key=_item_datetime_value)
    if sort == "date_desc":
        return sorted(items, key=_item_datetime_value, reverse=True)
    if sort == "from":
        return sorted(items, key=lambda item: (_message_sender(item) or "").lower())
    if sort == "to":
        return sorted(
            items,
            key=lambda item: str(getattr(item, "display_to", "") or "").lower(),
        )
    if sort == "subject":
        return sorted(
            items,
            key=lambda item: str(getattr(item, "subject", "") or "").lower(),
        )
    if sort == "attachments":
        return sorted(
            items,
            key=lambda item: bool(getattr(item, "has_attachments", False)),
            reverse=True,
        )
    if sort == "importance":
        return sorted(items, key=_item_importance_rank, reverse=True)
    return items


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

    def get_folder_counts(self, account: Account) -> dict[str, int | str]:
        return {
            "inbox": account.inbox.total_count,
            "sent": account.sent.total_count,
            "inbox_folder_id": _serialize_folder_id(account.inbox.id),
            "sent_folder_id": _serialize_folder_id(account.sent.id),
        }

    def list_mail_folders(self, account: Account) -> list[MailFolder]:
        root = account.msg_folder_root
        result: list[MailFolder] = []
        for folder in root.children:
            try:
                result.append(self._serialize_folder_tree(folder))
            except Exception:
                logger.debug("Skipping unreadable mail folder", exc_info=True)
        return result

    def _serialize_folder_tree(self, folder: Any, depth: int = 0) -> MailFolder:
        children: list[MailFolder] = []
        # Ограничиваем глубину, чтобы UI не зависал на очень больших mailbox.
        if depth < 3:
            try:
                for child in folder.children:
                    children.append(self._serialize_folder_tree(child, depth + 1))
            except Exception:
                logger.debug("Failed to read child mail folders", exc_info=True)

        return MailFolder(
            id=_serialize_folder_id(folder.id),
            name=folder.name or "Без имени",
            total_count=int(getattr(folder, "total_count", 0) or 0),
            unread_count=int(getattr(folder, "unread_count", 0) or 0),
            children=children,
        )

    def _resolve_mail_folder(self, account: Account, folder_id: str | None) -> Any:
        if folder_id is None:
            return account.inbox

        wanted_id = _parse_folder_id(folder_id)
        if str(account.inbox.id) == wanted_id:
            return account.inbox
        if str(account.sent.id) == wanted_id:
            return account.sent

        for folder in account.msg_folder_root.walk():
            if str(folder.id) == wanted_id:
                return folder

        raise EwsNotFoundError("Mail folder not found")

    def list_inbox_messages(
        self,
        account: Account,
        limit: int = 50,
        offset: int = 0,
        *,
        mail_filter: MailFilter = "all",
        sort: MailSort = "date_desc",
        user_email: str | None = None,
        folder_id: str | None = None,
    ) -> list[MailSummary]:
        folder = self._resolve_mail_folder(account, folder_id)
        serialized_folder_id = _serialize_folder_id(folder.id)
        predicate = _message_predicate(mail_filter, user_email)
        items: list[Any] = []
        order_by = _SORT_ORDER.get(sort, "-datetime_received")

        try:
            queryset = folder.all().only(*_INBOX_ONLY_FIELDS).order_by(order_by)
            if mail_filter == "flagged":
                queryset = queryset.filter(Q(followup_flag=2))

            items = _collect_inbox_page(
                queryset,
                limit=limit,
                offset=offset,
                predicate=predicate,
            )
        except Exception:
            # Некоторые типы EWS-папок не поддерживают сортировку/набор полей.
            # В этом случае деградируем к чтению с локальной фильтрацией.
            logger.warning(
                "Falling back to local folder iteration for mail list",
                exc_info=True,
            )
            fallback_items = _fallback_sort_items(list(folder.all()), sort)
            matched: list[Any] = []
            skipped = 0
            for item in fallback_items:
                if getattr(item, "id", None) is None:
                    continue
                if mail_filter == "flagged" and not _is_flagged(item):
                    continue
                if predicate is not None and not predicate(item):
                    continue
                if skipped < offset:
                    skipped += 1
                    continue
                matched.append(item)
                if len(matched) >= limit:
                    break
            items = matched

        result: list[MailSummary] = []

        for item in items:
            try:
                result.append(
                    _mail_summary_from_item(item, folder_id=serialized_folder_id)
                )
            except Exception:
                logger.warning(
                    "Skipping inbox message due to serialization error",
                    exc_info=True,
                )

        return result

    def get_message(
        self,
        account: Account,
        message_id: str,
        *,
        mark_read: bool = False,
        folder_id: str | None = None,
    ) -> MailDetail:
        folder = self._resolve_mail_folder(account, folder_id)
        item = _get_folder_item(folder, message_id)
        serialized_folder_id = _serialize_folder_id(folder.id)

        # Read attachments before save(): partial UpdateItem may drop the
        # in-memory attachment list on the exchangelib item instance.
        attachments = _attachments_from_item(account, item)

        if mark_read and not item.is_read:
            item.is_read = True
            item.save(update_fields=["is_read"])

        body, body_type = _extract_body(item)
        preview = _message_preview(item) or (
            _html_to_plain(body) if body_type == "html" else body[:300].strip()
        )
        has_attachments = bool(getattr(item, "has_attachments", False)) or bool(
            attachments
        )

        return MailDetail(
            id=_serialize_item_id(item.id),
            folder_id=serialized_folder_id,
            subject=item.subject or "(без темы)",
            sender=_message_sender(item),
            datetime_received=_to_iso(item.datetime_received),
            is_read=bool(item.is_read),
            preview=preview,
            has_attachments=has_attachments,
            body=body,
            body_type=body_type,
            attachments=attachments,
        )

    def get_attachment(
        self,
        account: Account,
        message_id: str,
        attachment_id: str,
        *,
        folder_id: str | None = None,
    ) -> tuple[bytes, str, str]:
        """Returns (content_bytes, filename, content_type)."""
        folder = self._resolve_mail_folder(account, folder_id)
        item = _get_folder_item(folder, message_id)

        for att in _load_raw_attachments(account, item):
            att_id = _attachment_id_str(att)
            if not att_id:
                continue
            if str(att_id) != attachment_id:
                continue
            try:
                content = att.content
            except Exception as exc:
                raise EwsConnectionError("Failed to fetch attachment content") from exc
            if content is None:
                raise EwsNotFoundError("Attachment content is empty")
            name = str(getattr(att, "name", None) or "attachment")
            mime = str(getattr(att, "content_type", None) or "application/octet-stream")
            return bytes(content), name, mime

        raise EwsNotFoundError("Attachment not found")

    def archive_messages(
        self,
        account: Account,
        message_ids: list[str],
        *,
        folder_id: str | None = None,
    ) -> tuple[list[str], dict[str, str]]:
        """Move messages to Archive. Returns (archived_ids, {failed_id: reason})."""
        folder = self._resolve_mail_folder(account, folder_id)
        try:
            archive_folder = _get_archive_folder(account)
        except EwsNotFoundError:
            return [], {mid: "Archive folder not found" for mid in message_ids}

        archived: list[str] = []
        errors: dict[str, str] = {}

        for msg_id in message_ids:
            try:
                item = _get_folder_item(folder, msg_id)
                item.move(archive_folder)
                archived.append(msg_id)
            except EwsNotFoundError as exc:
                errors[msg_id] = str(exc)
            except Exception as exc:
                logger.warning("Failed to archive message", exc_info=True)
                errors[msg_id] = "Failed to move to archive"

        return archived, errors

    def mark_message_read(
        self,
        account: Account,
        message_id: str,
        *,
        folder_id: str | None = None,
    ) -> MailSummary:
        folder = self._resolve_mail_folder(account, folder_id)
        item = _get_folder_item(folder, message_id)

        if not item.is_read:
            item.is_read = True
            item.save(update_fields=["is_read"])

        return _mail_summary_from_item(item, folder_id=_serialize_folder_id(folder.id))

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
