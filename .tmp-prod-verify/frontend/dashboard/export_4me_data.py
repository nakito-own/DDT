#!/usr/bin/env python3
"""Экспорт выгрузки 4me (Export 4me.xlsx) в JSON для отдельного дашборда."""

import json
from datetime import datetime
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Export 4me.xlsx"
OUT = Path(__file__).resolve().parent / "data" / "export-4me.json"

STATUS_LABELS = {
    "completed": "Завершено",
    "waiting_for_customer": "Ожидание действий от клиента",
    "in_progress": "В работе",
    "assigned": "Назначено",
}

CATEGORY_LABELS = {
    "incident": "Инцидент",
    "rfi": "Запрос информации",
    "rfc": "Запрос на изменение",
    "other": "Прочее",
}

IMPACT_LABELS = {
    "low": "Низкий",
    "medium": "Средний",
    "high": "Высокий",
}

COMPLETION_REASON_LABELS = {
    "solved": "Решено",
    "no_reply": "Нет ответа",
    "withdrawn": "Отозвано",
    "unsolvable": "Не решаемо",
    "gone": "Не актуально",
    "rejected": "Отклонено",
    "duplicate": "Дубликат",
    "workaround": "Обходное решение",
}


def clean_str(value):
    if pd.isna(value):
        return None
    text = str(value).strip()
    return text if text and text != "-" else None


def parse_dt(value):
    if pd.isna(value):
        return None
    try:
        return pd.to_datetime(value).isoformat()
    except Exception:
        return None


def to_naive_ts(value):
    if value is None:
        return None
    ts = pd.to_datetime(value)
    if ts.tzinfo is not None:
        ts = ts.tz_convert(None)
    return ts


def hours_between(start, end):
    if not start or not end:
        return None
    delta = to_naive_ts(end) - to_naive_ts(start)
    return round(delta.total_seconds() / 3600, 2)


def parse_resolution_duration(value):
    if pd.isna(value):
        return None
    text = str(value).strip()
    if ":" not in text:
        return None
    hours_part, minutes_part = text.split(":", 1)
    try:
        return round(int(hours_part) + int(minutes_part) / 60, 2)
    except ValueError:
        return None


def short_account(value):
    text = clean_str(value)
    if not text:
        return None
    text = text.replace(" @moscow", "").strip()
    return text.split("@")[0] if "@" in text else text


def short_service(value):
    text = clean_str(value) or "—"
    prefix = "КРР МР. "
    if text.startswith(prefix):
        return text[len(prefix):]
    return text


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


def format_template(value):
    if pd.isna(value):
        return None
    try:
        return str(int(float(value)))
    except (TypeError, ValueError):
        return clean_str(value)


def label_for(mapping, key):
    if not key:
        return None
    return mapping.get(key, key)


def build_record(row):
    request_id = int(row["ID"])
    status = clean_str(row.get("Status")) or ""
    category = clean_str(row.get("Category")) or "other"
    impact = clean_str(row.get("Impact"))

    created_at = parse_dt(row.get("Created At"))
    completed_at = parse_dt(row.get("Completed At"))
    resolution_target = parse_dt(row.get("Resolution Target"))

    resolution_hours = hours_between(created_at, completed_at)
    if resolution_hours is None:
        resolution_hours = parse_resolution_duration(row.get("Resolution Duration"))

    sla_met = None
    if resolution_target and completed_at:
        sla_met = to_naive_ts(completed_at) <= to_naive_ts(resolution_target)

    completion_reason = clean_str(row.get("Completion Reason"))
    resource = clean_str(row.get("#resource"))
    member = clean_str(row.get("Member"))
    service_instance = clean_str(row.get("Service Instance")) or "—"

    return {
        "id": request_id,
        "permalink": clean_str(row.get("Permalink")) or f"https://sc-tech-solutions.itsm.mos.ru/requests/{request_id}",
        "source": clean_str(row.get("Source")),
        "status": status,
        "statusLabel": label_for(STATUS_LABELS, status),
        "category": category,
        "categoryLabel": label_for(CATEGORY_LABELS, category),
        "impact": impact,
        "impactLabel": label_for(IMPACT_LABELS, impact) if impact else None,
        "serviceInstance": service_instance,
        "serviceShort": short_service(service_instance),
        "team": clean_str(row.get("Team")),
        "member": member,
        "memberShort": short_account(member),
        "subject": clean_str(row.get("Subject")),
        "organization": clean_str(row.get("Organization")),
        "requestedBy": clean_str(row.get("Requested By")),
        "requestedFor": clean_str(row.get("Requested For")),
        "template": format_template(row.get("Template")),
        "createdAt": created_at,
        "updatedAt": parse_dt(row.get("Updated At")),
        "completedAt": completed_at,
        "resolutionTarget": resolution_target,
        "resolutionHours": resolution_hours,
        "slaMet": sla_met,
        "completionReason": completion_reason,
        "completionReasonLabel": label_for(COMPLETION_REASON_LABELS, completion_reason) if completion_reason else None,
        "assignmentCount": int(row.get("Assignment Count") or 0),
        "reopenCount": int(row.get("Reopen Count") or 0),
        "reviewed": bool(row.get("Reviewed")) if not pd.isna(row.get("Reviewed")) else False,
        "urgent": bool(row.get("Urgent")) if not pd.isna(row.get("Urgent")) else False,
        "satisfaction": clean_str(row.get("Satisfaction")),
        "agileColumn": clean_str(row.get("Agile Board Column")),
        "resource": resource,
        "module": extract_module(resource),
        "isOpen": status != "completed",
        "isWaiting": status == "waiting_for_customer",
    }


def export(source=SOURCE, out_path=OUT):
    if not source.exists():
        raise FileNotFoundError(f"Не найден файл: {source}")

    df = pd.read_excel(source, sheet_name="Sheet1", header=0)
    use_cols = [c for c in df.columns if not str(c).startswith("Unnamed")]
    df = df[use_cols]
    df = df[df["ID"].notna()]

    records = [build_record(row) for _, row in df.iterrows()]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "4me",
        "exportedAt": datetime.now().strftime("%Y-%m-%d"),
        "sourceFile": source.name,
        "total": len(records),
        "records": records,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"Exported {len(records)} records from {source.name} -> {out_path}")
    return len(records)


def main():
    export()


if __name__ == "__main__":
    main()
