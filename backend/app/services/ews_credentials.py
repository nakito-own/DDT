def resolve_ews_username(email: str, username: str | None = None) -> str:
    if username and username.strip():
        return username.strip()
    local, separator, _rest = email.strip().partition("@")
    if not separator or not local:
        raise ValueError("Email must contain a local part before @")
    return local
