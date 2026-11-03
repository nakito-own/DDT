#!/usr/bin/env python3
"""Пересобрать data/requests.json из «Аналитика СТП.xlsx» в ../"""

import json
import re
from datetime import datetime
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Аналитика СТП.xlsx"
OUT = Path(__file__).parent / "data" / "requests.json"
MAIN_SHEET = "Заявки"
HEADER_CANDIDATES = (0, 1, 2)
ITSM_BASE = "https://sc-tech-solutions.itsm.mos.ru/requests/"
COMMENT_COLS = [f"Комментарий {i}" for i in range(1, 37)]
WAITING_PROMPT = re.compile(r"от\s+вас\s+ожида", re.IGNORECASE)


def parse_dt(value, time_value=None):
    if pd.isna(value):
        return None
    try:
        dt = pd.to_datetime(value, dayfirst=True)
        if time_value is not None and not pd.isna(time_value):
            t = pd.to_datetime(str(time_value)).time()
            dt = dt.replace(hour=t.hour, minute=t.minute, second=t.second)
        return dt.isoformat()
    except Exception:
        return None


def parse_custom_fields(text):
    result = {}
    if pd.isna(text):
        return result
    for line in str(text).split("\n"):
        line = line.strip()
        if ":" in line:
            key, val = line.split(":", 1)
            result[key.strip()] = val.strip()
    return result


def extract_module(url):
    if not url:
        return "Не указан"
    url = str(url).lower()
    if "landscaping" in url:
        return "landscaping"
    if "mydistrict" in url:
        return "mydistrict"
    if "f_work" in url or "/work" in url:
        return "Работы"
    if "task" in url or "задач" in url:
        return "Задачи"
    if "newsmart.mos.ru" in url or "smart.mos.ru" in url:
        return "smart.mos.ru"
    if url.startswith("http"):
        return "Прочее"
    return "Не указан"


def to_naive_ts(value):
    if value is None:
        return None
    ts = pd.to_datetime(value)
    if ts.tzinfo is not None:
        ts = ts.tz_convert(None)
    return ts


def clean_str(value):
    if pd.isna(value):
        return None
    text = str(value).strip()
    return text if text and text != "-" else None


def hours_between(start, end):
    if not start or not end:
        return None
    delta = to_naive_ts(end) - to_naive_ts(start)
    return round(delta.total_seconds() / 3600, 2)


def collect_text(row, columns):
    parts = []
    for col in columns:
        if col in row.index or col in row:
            value = clean_str(row.get(col))
            if value:
                parts.append(value)
    return " ".join(parts)


def infer_error_side(row, text_lower):
    status4me = clean_str(row.get("Статус 4me")) or ""
    status = clean_str(row.get("Статус")) or ""
    member = clean_str(row.get("Отвественный исполнитель")) or ""
    typ = clean_str(row.get("Тип")) or ""
    exec_comment = (clean_str(row.get("Комментарий исполнителя")) or "").lower()

    if "ецп" in text_lower or "ecp" in text_lower:
        return "ЕЦП"
    if any(x in text_lower for x in ("цифровой двойник", "цд 2", "цд2", " аис «ц")):
        return "ЦД"
    if status4me == "waiting_for_customer" or "Ожидание действий от клиента" in status.lower():
        return "Пользователь"
    user_hints = (
        "пусть",
        "уточнить",
        "пересоздать",
        "нет в системе",
        "пришлите",
        "скинут",
        "дайте ссылку",
        "пользовател",
    )
    if any(h in exec_comment for h in user_hints):
        return "Пользователь"
    if member.startswith("ДИТ"):
        return "ДИТ"
    if typ == "Доступ":
        return "ЕЦП"
    if typ in ("Ошибка", "Доработка"):
        return "КРР МР"
    if member.startswith("БС"):
        return "КРР МР"
    if typ == "Консультация":
        return "Пользователь"
    return "Не определено"


def status_group(status4me, status_ru, state):
    if state == "closed" or status_ru == "Завершено":
        return "closed"
    if status4me == "waiting_for_customer" or status_ru == "Ожидание действий от клиента действий от клиента":
        return "waiting"
    return "in_progress"


def is_waiting_reminder(text):
    return bool(WAITING_PROMPT.search(text or ""))


def extract_comment_timeline(row):
    comments = []
    for i in range(1, 37):
        text = clean_str(row.get(f"Комментарий {i}"))
        if not text:
            continue
        at = parse_dt(row.get(f"Дата комментария {i}"), row.get(f"Время комментария {i}"))
        if not at:
            continue
        comments.append({
            "at": at,
            "text": text,
            "author": clean_str(row.get(f"Автор {i}")) or "",
            "channel": clean_str(row.get(f"Канал комментария {i}")) or "",
        })
    return sorted(comments, key=lambda c: c["at"])


def compute_waiting_metrics(row, status_group, completed_at):
    comments = extract_comment_timeline(row)
    waiting_start = None

    for comment in comments:
        if is_waiting_reminder(comment["text"]):
            waiting_start = comment["at"]
            break

    if not waiting_start and status_group == "waiting" and comments:
        waiting_start = comments[-1]["at"]

    client_response_hours = None
    if waiting_start:
        end = None
        for comment in comments:
            if to_naive_ts(comment["at"]) <= to_naive_ts(waiting_start):
                continue
            if is_waiting_reminder(comment["text"]):
                continue
            end = comment["at"]
            break
        if not end and status_group != "waiting" and completed_at:
            end = completed_at
        if end:
            client_response_hours = hours_between(waiting_start, end)

    return {
        "waitingStartedAt": waiting_start,
        "clientResponseHours": client_response_hours,
        "hasWaitingEpisode": bool(waiting_start) or status_group == "waiting",
    }


def detect_header_row(source: Path, sheet_name: str) -> int | None:
    for header in HEADER_CANDIDATES:
        df = pd.read_excel(source, sheet_name=sheet_name, header=header, nrows=3)
        use_cols = [c for c in df.columns if not str(c).startswith("Unnamed")]
        if "ID заявки" in use_cols:
            return header
    return None


def version_sort_key(sheet_name: str) -> datetime:
    match = re.search(r"(\d{1,2})\.(\d{1,2})\.(\d{2,4})", sheet_name)
    if match:
        day, month, year = match.groups()
        year_num = int(year)
        if year_num < 100:
            year_num += 2000
        return datetime(year_num, int(month), int(day))
    if sheet_name == MAIN_SHEET:
        return datetime.max
    return datetime.min


def list_version_sheets(source: Path) -> list[str]:
    xl = pd.ExcelFile(source)
    sheets: list[str] = []
    for name in xl.sheet_names:
        if detect_header_row(source, name) is None:
            continue
        sheets.append(name)
    return sorted(sheets, key=version_sort_key)


def read_sheet(source: Path, sheet_name: str) -> pd.DataFrame:
    header = detect_header_row(source, sheet_name)
    if header is None:
        raise ValueError(f"На листе «{sheet_name}» не найдена строка заголовков с колонкой «ID заявки»")
    df = pd.read_excel(source, sheet_name=sheet_name, header=header)
    use_cols = [c for c in df.columns if not str(c).startswith("Unnamed")]
    df = df[use_cols]
    return df[df["ID заявки"].notna()]


def build_records(df: pd.DataFrame) -> list[dict]:
    text_cols = ["Тема", "Комментарий исполнителя", "Кастомные поля", *COMMENT_COLS]
    records = []

    for _, row in df.iterrows():
        custom = parse_custom_fields(row.get("Кастомные поля"))
        resource = custom.get("resource")
        close_time = custom.get("close_time")

        created_at = parse_dt(row.get("Дата создания"))
        completed_at = parse_dt(row.get("Дата закрытия"))
        work_taken_at = parse_dt(row.get("Дата комментария 2"), row.get("Время комментария 2"))
        comment1_at = parse_dt(row.get("Дата комментария 1"), row.get("Время комментария 1"))
        comment2_at = parse_dt(row.get("Дата комментария 2"), row.get("Время комментария 2"))
        sla_target = parse_dt(close_time) if close_time else None

        status4me = clean_str(row.get("Статус 4me"))
        status_ru = clean_str(row.get("Статус"))
        state = "closed" if status4me == "completed" else "open"

        resolution_hours = hours_between(created_at, completed_at)
        reaction_hours = hours_between(comment1_at, comment2_at)

        sla_met = None
        if sla_target and completed_at:
            sla_met = to_naive_ts(completed_at) <= to_naive_ts(sla_target)

        text_blob = collect_text(row, text_cols).lower()
        error_side = infer_error_side(row, text_blob)
        group = status_group(status4me, status_ru or "", state)
        waiting_metrics = compute_waiting_metrics(row, group, completed_at)

        request_id = int(row["ID заявки"])
        records.append(
            {
                "id": request_id,
                "state": state,
                "status": status_ru,
                "status4me": status4me,
                "statusGroup": group,
                "type": clean_str(row.get("Тип")),
                "block": clean_str(row.get("Блок")),
                "problemCategory": clean_str(row.get("Категория")),
                "subject": clean_str(row.get("Тема")),
                "solved": clean_str(row.get("Решено")),
                "userConfirmed": clean_str(row.get("Подтверждение от пользователя получено")),
                "member": clean_str(row.get("Отвественный исполнитель")),
                "requestedBy": clean_str(row.get("Заявитель")),
                "oiv": clean_str(row.get("ОИВ")),
                "organization": clean_str(row.get("Организация")),
                "errorSide": error_side,
                "createdAt": created_at,
                "workTakenAt": work_taken_at,
                "completedAt": completed_at,
                "slaTarget": sla_target,
                "resolutionHours": resolution_hours,
                "reactionHours": reaction_hours,
                "slaMet": sla_met,
                "module": extract_module(resource),
                "resource": resource,
                "commentCount": sum(1 for col in COMMENT_COLS if clean_str(row.get(col))),
                "permalink": f"{ITSM_BASE}{request_id}",
                **waiting_metrics,
            }
        )

    return records


def export(source: Path = SOURCE, out_path: Path = OUT) -> dict:
    if not source.exists():
        raise FileNotFoundError(f"Не найден файл: {source}")

    sheet_names = list_version_sheets(source)
    if not sheet_names:
        raise ValueError(f"В {source.name} не найдено листов с колонкой «ID заявки»")

    records_by_version: dict[str, list[dict]] = {}
    versions: list[dict] = []

    for sheet_name in sheet_names:
        df = read_sheet(source, sheet_name)
        records = build_records(df)
        records_by_version[sheet_name] = records
        versions.append({
            "id": sheet_name,
            "label": sheet_name,
            "total": len(records),
        })

    commit_sheets = [name for name in sheet_names if name != MAIN_SHEET]
    default_version = commit_sheets[-1] if commit_sheets else sheet_names[-1]
    default_total = len(records_by_version[default_version])

    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "stp",
        "exportedAt": datetime.now().strftime("%Y-%m-%d"),
        "sourceFile": source.name,
        "defaultVersion": default_version,
        "versions": versions,
        "recordsByVersion": records_by_version,
        "total": default_total,
        "records": records_by_version[default_version],
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"Exported {len(sheet_names)} version(s) from {source.name} -> {out_path}")
    for version in versions:
        print(f"  · {version['label']}: {version['total']} records")
    return payload


def main():
    export()


if __name__ == "__main__":
    main()
