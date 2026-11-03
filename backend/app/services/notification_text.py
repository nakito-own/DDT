"""Тексты уведомлений. Чистые функции, без Exchange и базы."""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

STATUS_LABELS = {
    "todo": "Запланировано",
    "in_progress": "В работе",
    "done": "Готово",
}

PRIORITY_LABELS = {
    "insignificant": "Незначительный",
    "low": "Низкий",
    "medium": "Средний",
    "high": "Высокий",
    "blocker": "Блокер",
}


def quote_name(value: str | None, *, fallback: str = "без названия") -> str:
    text = " ".join(str(value or "").split())
    if not text:
        text = fallback
    if len(text) > 140:
        text = text[:137].rstrip() + "…"
    return f"«{text}»"


def plain_text(value: str | None) -> str:
    import html
    import re

    text = html.unescape(str(value or ""))
    text = re.sub(r"(?i)<br\s*/?>", "\n", text)
    text = re.sub(r"(?i)</p\s*>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    return " ".join(text.split())


def format_when(
    value: datetime | None,
    zone: ZoneInfo,
    *,
    now: datetime | None = None,
) -> str:
    if value is None:
        return ""
    moment = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
    local = moment.astimezone(zone)
    current = (now or datetime.now(zone)).astimezone(zone)
    clock = local.strftime("%H:%M")
    if local.date() == current.date():
        return clock
    return f"{local.strftime('%d.%m.%Y')} {clock}"


def format_deadline(value: datetime | None, zone: ZoneInfo) -> str:
    if value is None:
        return ""
    moment = value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
    local = moment.astimezone(zone)
    return f"{local.strftime('%d.%m.%Y')} {local.strftime('%H:%M')}"


def _same_moment(left: datetime | None, right: datetime | None) -> bool:
    if left is None and right is None:
        return True
    if left is None or right is None:
        return False
    left_utc = (
        left if left.tzinfo is not None else left.replace(tzinfo=timezone.utc)
    ).astimezone(timezone.utc).replace(second=0, microsecond=0)
    right_utc = (
        right if right.tzinfo is not None else right.replace(tzinfo=timezone.utc)
    ).astimezone(timezone.utc).replace(second=0, microsecond=0)
    return left_utc == right_utc


def pack_messages(messages: list[str]) -> tuple[str, str]:
    cleaned = [message.strip() for message in messages if message and message.strip()]
    if not cleaned:
        return "", ""
    if len(cleaned) == 1:
        return cleaned[0], ""
    return cleaned[0], ". ".join(cleaned[1:])


def describe_new_mail(subject: str | None, sender: str | None) -> tuple[str, str]:
    title = f"Новое письмо {quote_name(subject, fallback='без темы')}"
    sender_name = " ".join(str(sender or "").split())
    body = f"От {sender_name}" if sender_name else ""
    return title, body


def describe_calendar_change(
    event_name: str,
    current: dict | None,
    previous: dict | None,
    *,
    zone: ZoneInfo,
    now: datetime | None = None,
) -> dict | None:
    """Возвращает title, body, silent и focus_at либо None, если событие не нужно."""
    subject = _calendar_subject(current) or _calendar_subject(previous)
    focus = _calendar_start(current) or _calendar_start(previous)
    named = quote_name(subject, fallback="без названия")

    if event_name == "DeletedEvent":
        title = f"Удалено событие {named}"
        return {
            "title": title,
            "body": "",
            "silent": False,
            "focus_at": focus,
            "subject": subject,
        }

    if event_name == "CreatedEvent":
        when = format_when(focus, zone, now=now)
        title = (
            f"Событие {named} назначено на {when}"
            if when
            else f"Создано событие {named}"
        )
        location = " ".join(str((current or {}).get("location") or "").split())
        return {
            "title": title,
            "body": location,
            "silent": False,
            "focus_at": focus,
            "subject": subject,
        }

    if event_name != "ModifiedEvent":
        return None

    if previous is None or current is None:
        return {
            "title": f"Обновлено событие {named}",
            "body": "",
            "silent": False,
            "focus_at": focus,
            "subject": subject,
        }

    messages: list[str] = []
    old_subject = _calendar_subject(previous)
    new_subject = _calendar_subject(current)
    if old_subject != new_subject:
        messages.append(
            f"Событие {quote_name(old_subject)} переименовано в {quote_name(new_subject)}"
        )

    if previous.get("body_known") and current.get("body_known"):
        if plain_text(previous.get("body")) != plain_text(current.get("body")):
            messages.append(f"Изменено описание события {named}")

    old_start = _calendar_start(previous)
    new_start = _calendar_start(current)
    if not _same_moment(old_start, new_start):
        when = format_when(new_start, zone, now=now)
        messages.append(
            f"Событие {named} назначено на {when}"
            if when
            else f"Снято время события {named}"
        )

    if _same_moment(old_start, new_start) and not _same_moment(
        previous.get("end"), current.get("end")
    ):
        when = format_when(current.get("end"), zone, now=now)
        messages.append(
            f"Изменено время окончания события {named}: {when}"
            if when
            else f"Снято время окончания события {named}"
        )

    old_location = " ".join(str(previous.get("location") or "").split())
    new_location = " ".join(str(current.get("location") or "").split())
    if old_location != new_location:
        if new_location:
            messages.append(f"Изменено место события {named}: {new_location}")
        else:
            messages.append(f"Удалено место события {named}")

    old_people = tuple(previous.get("attendees") or ())
    new_people = tuple(current.get("attendees") or ())
    if old_people != new_people:
        messages.append(f"Изменён список участников события {named}")

    if not messages:
        body_was_unknown = not previous.get("body_known")
        return {
            "title": f"Обновлено событие {named}",
            "body": "",
            "silent": not body_was_unknown,
            "focus_at": focus,
            "subject": subject,
        }

    title, body = pack_messages(messages)
    return {
        "title": title,
        "body": body,
        "silent": False,
        "focus_at": new_start or focus,
        "subject": new_subject or subject,
    }


def _calendar_subject(snapshot: dict | None) -> str:
    if not snapshot:
        return ""
    return " ".join(str(snapshot.get("subject") or "").split())


def _calendar_start(snapshot: dict | None) -> datetime | None:
    if not snapshot:
        return None
    value = snapshot.get("start")
    return value if isinstance(value, datetime) else None


def task_assigned_text(title: str | None) -> str:
    return f"Вам назначена задача {quote_name(title)}"


def task_responsible_text(title: str | None) -> str:
    return f"Вы назначены ответственным за задачу {quote_name(title)}"


def task_unassigned_text(title: str | None) -> str:
    return f"С вас снята задача {quote_name(title)}"


def task_unresponsible_text(title: str | None) -> str:
    return f"Вы больше не ответственный за задачу {quote_name(title)}"


def task_deleted_text(title: str | None) -> str:
    return f"Удалена задача {quote_name(title)}"


def task_comment_text(title: str | None, text: str) -> tuple[str, str]:
    preview = " ".join(text.split())
    if len(preview) > 160:
        preview = preview[:157].rstrip() + "…"
    return f"Новый комментарий к задаче {quote_name(title)}", preview


def describe_task_update(before: dict, after: dict, *, zone: ZoneInfo) -> list[str]:
    title = quote_name(after.get("title") or before.get("title"))
    messages: list[str] = []

    old_title = " ".join(str(before.get("title") or "").split())
    new_title = " ".join(str(after.get("title") or "").split())
    if old_title != new_title:
        messages.append(
            f"Задача {quote_name(old_title)} переименована в {quote_name(new_title)}"
        )

    if plain_text(before.get("description")) != plain_text(after.get("description")):
        messages.append(f"Изменено описание задачи {title}")

    old_status = str(before.get("status") or "")
    new_status = str(after.get("status") or "")
    if old_status != new_status:
        label = STATUS_LABELS.get(new_status, new_status or "без статуса")
        messages.append(f"Задача {title} переведена в статус «{label}»")

    old_priority = before.get("priority") or None
    new_priority = after.get("priority") or None
    if old_priority != new_priority:
        if new_priority:
            label = PRIORITY_LABELS.get(str(new_priority), str(new_priority))
            messages.append(f"Изменён приоритет задачи {title}: {label}")
        else:
            messages.append(f"Снят приоритет задачи {title}")

    if not _same_moment(before.get("deadline"), after.get("deadline")):
        when = format_deadline(after.get("deadline"), zone)
        messages.append(
            f"Изменён срок задачи {title}: {when}"
            if when
            else f"Снят срок задачи {title}"
        )

    if not _same_moment(before.get("time_start"), after.get("time_start")):
        when = format_when(after.get("time_start"), zone)
        messages.append(
            f"Задача {title} назначена на {when}"
            if when
            else f"Снято время начала задачи {title}"
        )

    if not _flag(before.get("archive")) and _flag(after.get("archive")):
        messages.append(f"Задача {title} перемещена в архив")

    return messages


def _flag(value) -> bool:
    return bool(value) and value not in {0, "0", "false", "False"}
