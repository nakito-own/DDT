"""HTTP API и раздача статики дашборда."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from .queries import (
    date_bounds,
    fourme_filter_options,
    query_fourme,
    query_stp,
    stp_filter_options,
)
from .store import DATASET_FILES, store

DASHBOARD_ROOT = Path(__file__).resolve().parent.parent

DATASET_INFO = {
    "stp": {
        "label": "Аналитика СТП",
        "title": "КРР МР — Аналитика СТП",
        "dateFields": ["createdAt", "workTakenAt", "completedAt", "slaTarget"],
    },
    "4me": {
        "label": "Export 4me",
        "title": "КРР МР — Export 4me",
        "dateFields": ["createdAt", "completedAt", "updatedAt", "resolutionTarget"],
    },
}


class FilterQuery(BaseModel):
    dateField: str = "createdAt"
    dateFrom: str | None = None
    dateTo: str | None = None
    multi: dict[str, list[str]] = Field(default_factory=dict)
    trendGroupBy: str = "month"
    tableLimit: int = Field(default=200, ge=1, le=500)
    tableOffset: int = Field(default=0, ge=0)
    version: str | None = None


app = FastAPI(title="Dashboard API", version="1.0.0")


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/datasets")
def list_datasets() -> list[dict[str, Any]]:
    result = []
    for dataset_id, info in DATASET_INFO.items():
        meta = store.meta(dataset_id)
        result.append({
            "id": dataset_id,
            "label": info["label"],
            "title": info["title"],
            "exportedAt": meta.exported_at,
            "sourceFile": meta.source_file,
            "total": meta.total,
        })
    return result


@app.get("/api/{dataset_id}/meta")
def dataset_meta(dataset_id: str, version: str | None = None) -> dict[str, Any]:
    _ensure_dataset(dataset_id)
    meta = store.meta(dataset_id, version)
    info = DATASET_INFO[dataset_id]
    bounds = date_bounds(store.records(dataset_id, meta.version), info["dateFields"])
    payload: dict[str, Any] = {
        "id": dataset_id,
        "schema": meta.schema,
        "exportedAt": meta.exported_at,
        "sourceFile": meta.source_file,
        "total": meta.total,
        "dateBounds": bounds,
    }
    if dataset_id == "stp":
        versions = store.versions(dataset_id)
        payload["versions"] = [
            {"id": item.id, "label": item.label, "total": item.total}
            for item in versions
        ]
        payload["defaultVersion"] = store.default_version(dataset_id)
        payload["version"] = meta.version
    return payload


@app.get("/api/{dataset_id}/filter-options")
def filter_options(dataset_id: str, version: str | None = None) -> dict[str, list[str]]:
    _ensure_dataset(dataset_id)
    resolved = store.resolve_version(dataset_id, version) if dataset_id == "stp" else None
    records = store.records(dataset_id, resolved)
    if dataset_id == "stp":
        return stp_filter_options(records)
    return fourme_filter_options(records)


@app.post("/api/{dataset_id}/query")
def query_dataset(dataset_id: str, body: FilterQuery) -> dict[str, Any]:
    _ensure_dataset(dataset_id)
    resolved = store.resolve_version(dataset_id, body.version) if dataset_id == "stp" else None
    records = store.records(dataset_id, resolved)
    kwargs = {
        "date_field": body.dateField,
        "date_from": body.dateFrom,
        "date_to": body.dateTo,
        "multi": body.multi,
        "trend_group_by": body.trendGroupBy,
        "table_limit": body.tableLimit,
        "table_offset": body.tableOffset,
    }
    if dataset_id == "stp":
        result = query_stp(records, **kwargs)
        result["version"] = resolved
        return result
    return query_fourme(records, **kwargs)


@app.post("/api/reload")
def reload_cache(dataset_id: str | None = None) -> dict[str, str]:
    store.reload(dataset_id)
    return {"status": "reloaded", "dataset": dataset_id or "all"}


def _ensure_dataset(dataset_id: str) -> None:
    if dataset_id not in DATASET_FILES:
        raise HTTPException(status_code=404, detail=f"Unknown dataset: {dataset_id}")


app.mount("/", StaticFiles(directory=DASHBOARD_ROOT, html=True), name="static")


def main() -> None:
    import argparse
    import os

    import uvicorn

    parser = argparse.ArgumentParser(description="Дашборд: API + статика")
    parser.add_argument(
        "--host",
        default=os.environ.get("HOST", "127.0.0.1"),
        help="IP/хост публикации (0.0.0.0 — все интерфейсы, по умолчанию 127.0.0.1)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("PORT", "8765")),
        help="Порт (по умолчанию 8765)",
    )
    parser.add_argument(
        "--no-reload",
        action="store_true",
        help="Отключить автоперезагрузку при изменении кода",
    )
    args = parser.parse_args()

    print(f"Дашборд: http://{args.host}:{args.port}")
    uvicorn.run(
        "server.app:app",
        host=args.host,
        port=args.port,
        reload=not args.no_reload,
    )


if __name__ == "__main__":
    main()
