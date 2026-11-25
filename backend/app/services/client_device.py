"""Device name and OS captured when a session is created."""

import re
from urllib.parse import unquote

_DEVICE_NAME_LIMIT = 255
_OS_NAME_LIMIT = 128


def clean_label(value: str | None, limit: int) -> str | None:
    if value is None:
        return None
    text = unquote(value).replace("\x00", "").strip()
    text = re.sub(r"\s+", " ", text)
    if not text:
        return None
    return text[:limit]


def resolve_device_labels(
    device_name: str | None,
    os_name: str | None,
    user_agent: str | None,
) -> tuple[str | None, str | None]:
    name = clean_label(device_name, _DEVICE_NAME_LIMIT)
    operating_system = clean_label(os_name, _OS_NAME_LIMIT)
    if name and operating_system:
        return name, operating_system

    parsed_name, parsed_os = parse_user_agent(user_agent or "")
    return name or parsed_name, operating_system or parsed_os


def parse_user_agent(user_agent: str) -> tuple[str | None, str | None]:
    ua = user_agent.strip()
    if not ua or ua.lower().startswith("dart/"):
        return None, None

    browser = _browser_name(ua)
    device = _device_name(ua, browser)
    operating_system = _os_name(ua)
    return (
        clean_label(device, _DEVICE_NAME_LIMIT),
        clean_label(operating_system, _OS_NAME_LIMIT),
    )


def _browser_name(ua: str) -> str:
    lower = ua.lower()
    if "edg/" in lower:
        return "Edge"
    if "opr/" in lower or "opera" in lower:
        return "Opera"
    if "yabrowser" in lower:
        return "Яндекс Браузер"
    if "firefox/" in lower:
        return "Firefox"
    if "chrome/" in lower or "crios/" in lower:
        return "Chrome"
    if "safari/" in lower:
        return "Safari"
    return "Браузер"


def _device_name(ua: str, browser: str) -> str:
    if "iPhone" in ua:
        return f"{browser}, iPhone"
    if "iPad" in ua:
        return f"{browser}, iPad"
    android = re.search(r"Android [^;)]*;\s*([^;)]+)", ua)
    if android:
        model = android.group(1).strip()
        if model and model.lower() not in {"linux", "u", "k"}:
            return f"{browser}, {model}"
        return f"{browser}, Android"
    if "Macintosh" in ua:
        return f"{browser}, Mac"
    if "Windows" in ua:
        return f"{browser}, Windows"
    if "CrOS" in ua:
        return f"{browser}, Chromebook"
    if "Linux" in ua:
        return f"{browser}, Linux"
    return browser


def _os_name(ua: str) -> str | None:
    mac = re.search(r"Mac OS X (\d+)[_.](\d+)(?:[_.](\d+))?", ua)
    if mac:
        version = f"{mac.group(1)}.{mac.group(2)}"
        if mac.group(3):
            version = f"{version}.{mac.group(3)}"
        return f"macOS {version}"
    ios = re.search(r"(?:CPU )?OS (\d+)[_.](\d+)", ua) if ("iPhone" in ua or "iPad" in ua) else None
    if ios:
        return f"iOS {ios.group(1)}.{ios.group(2)}"
    android = re.search(r"Android (\d+(?:\.\d+)?)", ua)
    if android:
        return f"Android {android.group(1)}"
    if "Windows" in ua:
        return "Windows"
    if "CrOS" in ua:
        return "ChromeOS"
    if "Linux" in ua:
        return "Linux"
    if "Macintosh" in ua:
        return "macOS"
    return None
