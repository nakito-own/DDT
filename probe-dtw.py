#!/usr/bin/env python3
"""Проверка авторизации DTW и постраничной выдачи набора КРР.

Берёт DTW_BASE_URL, DTW_LOGIN, DTW_PASSWORD и DTW_DATASET_ID из .env
рядом со скриптом. Пароль и accessToken не печатает.

Запуск из корня репозитория:

    python3 probe-dtw.py
"""

from __future__ import annotations

import json
import ssl
import sys
import uuid
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PAGE_SIZE = 3
TIMEOUT = 90
FILTERS = [
    {
        "fieldName": "dk",
        "values": ["true", "false", None],
        "conditionType": "Equal",
    }
]
TOKEN_KEYS = ("accessToken", "access_token", "token")
PAGING_MODES = (
    ("offset", "count"),
    ("skip", "take"),
    ("offset", "limit"),
    ("page", "pageSize"),
    ("pageNumber", "pageSize"),
    ("$skip", "$top"),
)


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def request(url: str, data: bytes, headers: dict[str, str]) -> tuple[int, bytes]:
    opener = urllib.request.Request(url, data=data, headers=headers, method="POST")
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(opener, timeout=TIMEOUT, context=context) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def parse_json(body: bytes) -> object | None:
    try:
        return json.loads(body.decode())
    except ValueError:
        return None


def preview(body: bytes, limit: int = 220) -> str:
    return " ".join(body.decode(errors="replace").split())[:limit]


def find_token(payload: object) -> tuple[str, str] | None:
    if not isinstance(payload, dict):
        return None
    for key in TOKEN_KEYS:
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return key, value.strip()
    nested = payload.get("data")
    if isinstance(nested, dict):
        found = find_token(nested)
        if found:
            return f"data.{found[0]}", found[1]
    return None


def login(base: str, user: str, password: str) -> str:
    url = f"{base}/app/auth/login"
    boundary = uuid.uuid4().hex
    multipart = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="login"\r\n\r\n{user}\r\n'
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="password"\r\n\r\n{password}\r\n'
        f"--{boundary}--\r\n"
    ).encode()
    attempts = (
        (
            "multipart",
            multipart,
            {"Content-Type": f"multipart/form-data; boundary={boundary}"},
        ),
        (
            "urlencoded",
            urllib.parse.urlencode({"login": user, "password": password}).encode(),
            {"Content-Type": "application/x-www-form-urlencoded"},
        ),
    )
    for name, body, headers in attempts:
        status, response = request(url, body, {**headers, "Accept": "application/json"})
        payload = parse_json(response)
        found = find_token(payload)
        keys = sorted(payload) if isinstance(payload, dict) else []
        print(f"login {name}: HTTP {status}, bytes={len(response)}, keys={keys}")
        if found:
            print(f"token field: {found[0]}, length={len(found[1])}")
            return found[1]
        if status >= 400:
            print(f"login {name} body: {preview(response)}")
    raise SystemExit("Авторизация не вернула accessToken")


def fetch_page(url: str, token: str, params: dict[str, int]) -> dict[str, object]:
    query = urllib.parse.urlencode(params)
    status, body = request(
        f"{url}?{query}",
        json.dumps(FILTERS).encode(),
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    result: dict[str, object] = {"status": status, "bytes": len(body), "params": params}
    payload = parse_json(body)
    if not isinstance(payload, dict):
        result["body"] = preview(body)
        return result
    if status >= 400:
        detail = payload.get("message") or payload.get("detail") or payload.get("title") or payload.get("error")
        result["detail"] = detail if isinstance(detail, str) else preview(body)
        return result
    rows = payload.get("data")
    ids = [
        row.get("id_unique")
        for row in rows
        if isinstance(row, dict)
    ] if isinstance(rows, list) else []
    result.update(
        {
            "name": payload.get("name"),
            "totalCount": payload.get("totalCount"),
            "count": payload.get("count"),
            "rows": len(ids),
            "ids": ids,
        }
    )
    return result


def page_params(offset_name: str, limit_name: str, index: int) -> dict[str, int]:
    # page and pageNumber are positions, not row offsets.
    if offset_name in {"page", "pageNumber"}:
        start = 0 if offset_name == "page" else 1
        return {offset_name: start + index, limit_name: PAGE_SIZE}
    return {offset_name: index * PAGE_SIZE, limit_name: PAGE_SIZE}


def show(page: dict[str, object]) -> None:
    print(json.dumps(page, ensure_ascii=False))


def pages_differ(left: dict[str, object], right: dict[str, object]) -> bool:
    left_ids = left.get("ids")
    right_ids = right.get("ids")
    return isinstance(left_ids, list) and isinstance(right_ids, list) and left_ids != right_ids and bool(left_ids)


def main() -> None:
    env = load_env(ROOT / ".env")
    base = env.get("DTW_BASE_URL", "https://dtwapi.mos.ru").rstrip("/")
    user = env.get("DTW_LOGIN", "")
    password = env.get("DTW_PASSWORD", "")
    dataset = env.get("DTW_DATASET_ID", "28107")
    if not user or not password:
        raise SystemExit("В .env нужны DTW_LOGIN и DTW_PASSWORD")

    print(f"dataset {dataset} at {base}")
    token = login(base, user, password)
    url = f"{base}/app/api/data-output/datasets/GetDataWithRequestByFilters/{dataset}"

    configured = (
        env.get("DTW_OFFSET_PARAM", "offset"),
        env.get("DTW_LIMIT_PARAM", "limit"),
    )
    modes = (configured,) + tuple(mode for mode in PAGING_MODES if mode != configured)
    for offset_name, limit_name in modes:
        print(f"\npaging {offset_name}/{limit_name}")
        fetched = [
            fetch_page(url, token, page_params(offset_name, limit_name, index))
            for index in range(3)
        ]
        for page in fetched:
            show(page)
        if pages_differ(fetched[0], fetched[1]):
            third_ok = pages_differ(fetched[1], fetched[2])
            print(
                f"pages advance with {offset_name}/{limit_name}; "
                f"third page is distinct: {third_ok}"
            )
            return
        if fetched[0].get("status") != 200:
            print("this paging mode was rejected")
            continue
        print("page repeated or was empty")

    raise SystemExit("Ни один вариант параметров не сдвинул страницу")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.URLError as exc:
        raise SystemExit(f"Сеть недоступна: {exc.reason}") from exc
    except TimeoutError:
        raise SystemExit("Истекло время ожидания ответа DTW")
