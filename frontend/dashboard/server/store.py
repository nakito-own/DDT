"""Загрузка и кэширование датасетов дашборда."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DASHBOARD_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = DASHBOARD_ROOT / "data"

DATASET_FILES = {
    "stp": DATA_DIR / "requests.json",
    "4me": DATA_DIR / "export-4me.json",
}


@dataclass(frozen=True)
class DatasetMeta:
    id: str
    schema: str
    exported_at: str
    source_file: str
    total: int
    version: str | None = None


@dataclass(frozen=True)
class VersionInfo:
    id: str
    label: str
    total: int


class DatasetStore:
    def __init__(self) -> None:
        self._cache: dict[str, dict[str, Any]] = {}

    def load(self, dataset_id: str) -> dict[str, Any]:
        if dataset_id not in DATASET_FILES:
            raise KeyError(dataset_id)
        if dataset_id not in self._cache:
            path = DATASET_FILES[dataset_id]
            with path.open(encoding="utf-8") as fh:
                self._cache[dataset_id] = json.load(fh)
        return self._cache[dataset_id]

    def versions(self, dataset_id: str) -> list[VersionInfo]:
        data = self.load(dataset_id)
        raw_versions = data.get("versions")
        if not raw_versions:
            return [VersionInfo(id="default", label="default", total=len(data.get("records", [])))]
        return [
            VersionInfo(
                id=item["id"],
                label=item.get("label", item["id"]),
                total=item.get("total", 0),
            )
            for item in raw_versions
        ]

    def default_version(self, dataset_id: str) -> str | None:
        data = self.load(dataset_id)
        if data.get("recordsByVersion"):
            return data.get("defaultVersion") or data["versions"][0]["id"]
        return None

    def resolve_version(self, dataset_id: str, version: str | None) -> str | None:
        data = self.load(dataset_id)
        records_by_version = data.get("recordsByVersion")
        if not records_by_version:
            return None

        if version and version in records_by_version:
            return version

        default = self.default_version(dataset_id)
        if default and default in records_by_version:
            return default
        return next(iter(records_by_version))

    def meta(self, dataset_id: str, version: str | None = None) -> DatasetMeta:
        data = self.load(dataset_id)
        resolved = self.resolve_version(dataset_id, version)
        records = self.records(dataset_id, resolved)
        return DatasetMeta(
            id=dataset_id,
            schema=data.get("schema", dataset_id),
            exported_at=data.get("exportedAt", "—"),
            source_file=data.get("sourceFile", "—"),
            total=len(records),
            version=resolved,
        )

    def records(self, dataset_id: str, version: str | None = None) -> list[dict[str, Any]]:
        data = self.load(dataset_id)
        records_by_version = data.get("recordsByVersion")
        if records_by_version:
            resolved = self.resolve_version(dataset_id, version)
            if resolved:
                return records_by_version.get(resolved, [])
            return []

        return data.get("records", [])

    def reload(self, dataset_id: str | None = None) -> None:
        if dataset_id is None:
            self._cache.clear()
            return
        self._cache.pop(dataset_id, None)


store = DatasetStore()
