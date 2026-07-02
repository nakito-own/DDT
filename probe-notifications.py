#!/usr/bin/env python3
"""
Probe notification capabilities on an Exchange / OWA server.

Tests:
  1. EWS pull / streaming / push subscriptions (exchangelib — same stack as DDT backend)
  2. OWA internal SubscribeToNotification for each known notification type

Credentials from .env (same as test-ews.py):
  EWS_USERNAME, EWS_PASSWORD, EWS_EMAIL, EWS_SERVER (default: owa.mos.ru)
"""

from __future__ import annotations

import json
import os
import re
import sys
import uuid
from dataclasses import dataclass
from typing import Any
from urllib.parse import urljoin

import requests
from dotenv import load_dotenv
from exchangelib import Account, Configuration, Credentials, DELEGATE
from exchangelib.errors import ErrorInvalidSubscriptionRequest, ResponseMessageError
from exchangelib.services import SubscribeToPull, SubscribeToStreaming, SubscribeToPush

load_dotenv()

SERVER = os.getenv("EWS_SERVER", "owa.mos.ru")
USERNAME = os.getenv("EWS_USERNAME", "")
PASSWORD = os.getenv("EWS_PASSWORD", "")
EMAIL = os.getenv("EWS_EMAIL", "")

OWA_NOTIFICATION_TYPES = [
    "HierarchyNotification",
    "ReminderNotification",
    "NewMailNotification",
    "SocialActivityNotification",
    "SuiteNotification",
]

EWS_EVENT_TYPES = ["NewMailEvent", "CreatedEvent", "ModifiedEvent"]


@dataclass
class ProbeResult:
    name: str
    supported: bool | None  # None = inconclusive
    detail: str


def _require_credentials() -> None:
    missing = [
        name
        for name, value in [
            ("EWS_USERNAME", USERNAME),
            ("EWS_PASSWORD", PASSWORD),
            ("EWS_EMAIL", EMAIL),
        ]
        if not value
    ]
    if missing:
        print(f"Missing env vars: {', '.join(missing)}")
        print("Set them in .env (see .env.example) and rerun.")
        sys.exit(1)


def _create_account() -> Account:
    credentials = Credentials(username=USERNAME, password=PASSWORD)
    config = Configuration(
        server=SERVER,
        credentials=credentials,
        auth_type=None,
    )
    account = Account(
        primary_smtp_address=EMAIL,
        config=config,
        autodiscover=False,
        access_type=DELEGATE,
    )
    _ = account.inbox.total_count
    return account


def _ews_probe(name: str, fn) -> ProbeResult:
    try:
        result = fn()
        return ProbeResult(name=name, supported=True, detail=result)
    except ErrorInvalidSubscriptionRequest as exc:
        return ProbeResult(name=name, supported=False, detail=str(exc))
    except ResponseMessageError as exc:
        msg = str(exc)
        if "ErrorInvalidSubscription" in msg or "NotSupported" in msg:
            return ProbeResult(name=name, supported=False, detail=msg)
        return ProbeResult(name=name, supported=None, detail=msg)
    except Exception as exc:
        return ProbeResult(name=name, supported=None, detail=f"{type(exc).__name__}: {exc}")


def probe_ews(account: Account) -> list[ProbeResult]:
    results: list[ProbeResult] = []

    def pull_subscribe() -> str:
        sub_id, watermark = account.inbox.subscribe_to_pull(
            event_types=EWS_EVENT_TYPES,
            timeout=10,
        )
        account.inbox.unsubscribe(sub_id)
        return f"subscription_id={sub_id[:8]}..., watermark={watermark[:16]}..."

    results.append(_ews_probe("EWS Pull (inbox)", pull_subscribe))

    def streaming_subscribe() -> str:
        sub_id = account.inbox.subscribe_to_streaming(event_types=EWS_EVENT_TYPES)
        account.inbox.unsubscribe(sub_id)
        return f"subscription_id={sub_id[:8]}..."

    results.append(_ews_probe("EWS Streaming (inbox)", streaming_subscribe))

    def push_subscribe() -> str:
        # Dummy callback — we only check whether the server accepts the subscription request.
        sub_id, _watermark = account.inbox.subscribe_to_push(
            callback_url="https://example.invalid/ews-push-callback",
            event_types=EWS_EVENT_TYPES,
            status_frequency=1,
        )
        account.inbox.unsubscribe(sub_id)
        return f"subscription_id={sub_id[:8]}... (server accepted subscribe request)"

    results.append(_ews_probe("EWS Push (inbox, dummy callback URL)", push_subscribe))

    def calendar_pull() -> str:
        sub_id, watermark = account.calendar.subscribe_to_pull(
            event_types=["CreatedEvent", "ModifiedEvent", "DeletedEvent"],
            timeout=10,
        )
        account.calendar.unsubscribe(sub_id)
        return f"subscription_id={sub_id[:8]}..., watermark={watermark[:16]}..."

    results.append(_ews_probe("EWS Pull (calendar)", calendar_pull))

    return results


def _owa_base_url() -> str:
    return f"https://{SERVER}/owa/"


def _owa_login(session: requests.Session) -> tuple[bool, str]:
    """Form-login to OWA and capture session cookies + canary token."""
    base = _owa_base_url()
    auth_url = urljoin(base, "auth.owa")

    response = session.post(
        auth_url,
        data={
            "destination": base,
            "flags": "4",
            "forcedownlevel": "0",
            "username": USERNAME,
            "password": PASSWORD,
            "isOutlook": "1",
            "passwordText": "",
            "isUtf8": "1",
        },
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "Mozilla/5.0 (compatible; DDT-notification-probe/1.0)",
        },
        allow_redirects=True,
        timeout=30,
    )

    if response.status_code >= 400:
        return False, f"auth.owa HTTP {response.status_code}"

    html = response.text
    canary_match = re.search(
        r'(?:name="canary"|id="canary")[^>]*value="([^"]+)"',
        html,
        re.IGNORECASE,
    )
    canary = canary_match.group(1) if canary_match else None

    if "reason=2" in response.url or "logon.aspx" in response.url.lower():
        return False, "OWA login rejected (check username/password)"

    if not session.cookies:
        return False, "OWA login returned no cookies"

    detail = f"cookies={len(session.cookies)}, canary={'yes' if canary else 'no'}"
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0 (compatible; DDT-notification-probe/1.0)",
            "Accept": "application/json, text/plain, */*",
            "Content-Type": "application/json; charset=utf-8",
            "Action": "SubscribeToNotification",
            "X-AnchorMailbox": EMAIL,
            "X-Owa-ExplicitLogonUser": EMAIL,
            "X-Owa-CorrelationId": str(uuid.uuid4()),
            "X-Req-Source": "Mail",
        }
    )
    if canary:
        session.headers["X-OWA-CANARY"] = canary

    return True, detail


def _parse_owa_subscribe_response(raw: Any) -> list[dict[str, Any]]:
    if isinstance(raw, list):
        return [item for item in raw if isinstance(item, dict)]
    if isinstance(raw, dict):
        if "Body" in raw and isinstance(raw["Body"], list):
            return [item for item in raw["Body"] if isinstance(item, dict)]
        return [raw]
    return []


def _owa_subscribe(
    session: requests.Session,
    notification_types: list[str],
    *,
    request_id: int = -19,
) -> tuple[int, list[dict[str, Any]], str]:
    url = (
        f"https://{SERVER}/owa/service.svc"
        f"?action=SubscribeToNotification&EP=1&UA=0&ID={request_id}&AC=1"
    )
    body_variants = [
        notification_types,
        {"SubscriptionIds": notification_types},
        {"subscriptionIds": notification_types},
        {"Body": {"SubscriptionIds": notification_types}},
        None,
    ]

    last_error = ""
    for body in body_variants:
        try:
            response = session.post(url, json=body, timeout=30)
            last_error = f"HTTP {response.status_code}"
            if response.status_code >= 400:
                continue
            content_type = response.headers.get("Content-Type", "")
            if "json" not in content_type.lower() and response.text.lstrip().startswith("<"):
                last_error = "HTML response (session may have expired)"
                continue
            parsed = response.json()
            items = _parse_owa_subscribe_response(parsed)
            if items:
                body_label = "null" if body is None else json.dumps(body, ensure_ascii=False)
                return response.status_code, items, body_label
        except requests.RequestException as exc:
            last_error = str(exc)
        except json.JSONDecodeError:
            last_error = "non-JSON response"

    return 0, [], last_error


def probe_owa() -> tuple[list[ProbeResult], str | None]:
    session = requests.Session()
    ok, login_detail = _owa_login(session)
    if not ok:
        return [], f"OWA login failed: {login_detail}"

    login_info = login_detail
    results: list[ProbeResult] = []

    # Batch probe — same pattern as real OWA client.
    status, items, body_used = _owa_subscribe(session, OWA_NOTIFICATION_TYPES)
    if not items:
        results.append(
            ProbeResult(
                name="OWA batch SubscribeToNotification",
                supported=None,
                detail=f"No parseable response ({body_used})",
            )
        )
    else:
        for item in items:
            sub_id = item.get("SubscriptionId", "?")
            created = item.get("SuccessfullyCreated")
            error = item.get("ErrorInfo") or item.get("ErrorMessage") or ""
            exists = item.get("SubscriptionExists")
            supported = True if created is True else False if created is False else None
            detail_parts = [f"SuccessfullyCreated={created}", f"SubscriptionExists={exists}"]
            if error:
                detail_parts.append(f"ErrorInfo={error}")
            results.append(
                ProbeResult(
                    name=f"OWA {sub_id}",
                    supported=supported,
                    detail=", ".join(detail_parts),
                )
            )

    # Individual probes — clearer per-type signal if batch body format differs.
    seen_ids = {r.name.removeprefix("OWA ") for r in results}
    for notification_type in OWA_NOTIFICATION_TYPES:
        if notification_type in seen_ids:
            continue
        _status, items, body_used = _owa_subscribe(
            session, [notification_type], request_id=-(hash(notification_type) % 1000)
        )
        if not items:
            results.append(
                ProbeResult(
                    name=f"OWA {notification_type} (single)",
                    supported=None,
                    detail=f"No response ({body_used})",
                )
            )
            continue
        item = items[0]
        created = item.get("SuccessfullyCreated")
        error = item.get("ErrorInfo") or item.get("ErrorMessage") or ""
        supported = True if created is True else False if created is False else None
        detail = f"SuccessfullyCreated={created}"
        if error:
            detail += f", ErrorInfo={error}"
        results.append(
            ProbeResult(
                name=f"OWA {notification_type} (single)",
                supported=supported,
                detail=detail,
            )
        )

    return results, login_info


def _print_section(title: str, results: list[ProbeResult]) -> None:
    print(f"\n{'=' * 72}")
    print(title)
    print("=" * 72)
    if not results:
        print("  (no results)")
        return

    icon = {True: "OK  ", False: "FAIL", None: "??? "}
    for result in results:
        mark = icon[result.supported]
        print(f"  [{mark}] {result.name}")
        print(f"         {result.detail}")


def main() -> None:
    _require_credentials()
    print(f"Server: {SERVER}")
    print(f"Mailbox: {EMAIL}")

    print("\nConnecting via EWS...")
    account = _create_account()
    print("EWS connection OK")

    ews_results = probe_ews(account)
    _print_section("EWS NOTIFICATIONS (recommended for DDT)", ews_results)

    print("\nLogging into OWA for internal API probe...")
    owa_results, owa_login = probe_owa()
    if owa_login is None:
        print(f"OWA probe skipped: {owa_results}")
    else:
        print(f"OWA session: {owa_login}")
        _print_section("OWA INTERNAL SubscribeToNotification", owa_results)

    supported_ews = [r.name for r in ews_results if r.supported is True]
    supported_owa = [r.name for r in owa_results if r.supported is True]

    print(f"\n{'=' * 72}")
    print("SUMMARY")
    print("=" * 72)
    if supported_ews:
        print("EWS supported:")
        for name in supported_ews:
            print(f"  - {name}")
    else:
        print("EWS: no subscriptions confirmed")

    if owa_login is not None:
        if supported_owa:
            print("OWA internal supported:")
            for name in supported_owa:
                print(f"  - {name}")
        else:
            print("OWA internal: no SubscribeToNotification types confirmed")

    print(
        "\nNote: For DDT, prefer EWS Streaming or Pull — they work with the existing "
        "exchangelib backend and do not require OWA session cookies."
    )


if __name__ == "__main__":
    main()
