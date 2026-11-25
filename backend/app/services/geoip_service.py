"""Country of the client IP, resolved when a session is opened."""

import ipaddress
import logging
from threading import Lock

import requests
from fastapi import Request

logger = logging.getLogger(__name__)

_LOCAL_COUNTRY = "Локальная сеть"
_cache: dict[str, str] = {}
_cache_lock = Lock()


def client_ip(request: Request) -> str | None:
    for header in ("x-real-ip", "x-forwarded-for"):
        raw = request.headers.get(header)
        if not raw:
            continue
        candidate = raw.split(",")[0].strip()
        if _parse_ip(candidate) is not None:
            return candidate
    if request.client is None:
        return None
    host = (request.client.host or "").strip()
    if _parse_ip(host) is None:
        return None
    return host


def country_for_ip(ip: str | None) -> str | None:
    address = _parse_ip(ip or "")
    if address is None:
        return None
    key = str(address)
    with _cache_lock:
        cached = _cache.get(key)
    if cached is not None:
        return cached

    if (
        address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_reserved
        or address.is_unspecified
    ):
        _remember(key, _LOCAL_COUNTRY)
        return _LOCAL_COUNTRY

    country = _lookup_public(key)
    if country:
        _remember(key, country)
    return country


def _parse_ip(value: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address | None:
    try:
        address = ipaddress.ip_address(value.strip())
    except ValueError:
        return None
    if isinstance(address, ipaddress.IPv6Address) and address.ipv4_mapped is not None:
        return address.ipv4_mapped
    return address


def _remember(ip: str, country: str) -> None:
    with _cache_lock:
        if len(_cache) > 2048:
            _cache.clear()
        _cache[ip] = country


def _lookup_public(ip: str) -> str | None:
    try:
        response = requests.get(
            f"http://ip-api.com/json/{ip}",
            params={"fields": "status,country", "lang": "ru"},
            timeout=2,
        )
        response.raise_for_status()
        payload = response.json()
    except Exception:
        logger.info("IP country lookup failed")
        return None
    if not isinstance(payload, dict) or payload.get("status") != "success":
        return None
    country = payload.get("country")
    if not isinstance(country, str):
        return None
    country = country.strip()
    if not country:
        return None
    return country[:128]
