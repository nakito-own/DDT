import re

TASK_KEY_PATTERN = re.compile(r"^(?P<prefix>[A-Za-z0-9][A-Za-z0-9._-]*)-(?P<number>\d+)$")
SPACE_KEY_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9]*$")


def normalize_user_key_prefix(raw: str) -> str:
    value = (raw or "").strip()
    if "\\" in value:
        value = value.rsplit("\\", 1)[-1]
    if "/" in value:
        value = value.rsplit("/", 1)[-1]
    if "@" in value:
        value = value.split("@", 1)[0]
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "", value).lower()
    if not cleaned or not cleaned[0].isalnum():
        return "user"
    return cleaned[:80]


def normalize_space_key(raw: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "", raw or "").upper()
    if not cleaned or not cleaned[0].isalpha():
        return "SPACE"
    return cleaned[:64]


def parse_task_key(value: str) -> tuple[str, int] | None:
    match = TASK_KEY_PATTERN.fullmatch((value or "").strip())
    if not match:
        return None
    return match.group("prefix"), int(match.group("number"))


def is_task_key(value: str) -> bool:
    return parse_task_key(value) is not None


def build_task_key(prefix: str, number: int) -> str:
    return f"{prefix}-{number}"
