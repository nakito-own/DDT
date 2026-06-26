import base64
import hashlib
import logging

from cryptography.fernet import Fernet, InvalidToken

from app.config import settings

logger = logging.getLogger(__name__)

_DEV_KEY = b"ddt-dev-ews-key-change-in-production!!"


class CryptoService:
    def __init__(self) -> None:
        self._fernet = Fernet(self._resolve_key())

    def _resolve_key(self) -> bytes:
        raw = settings.ews_credentials_key.strip()
        if raw:
            return raw.encode() if isinstance(raw, str) else raw

        logger.warning(
            "EWS_CREDENTIALS_KEY is not set; using development-only encryption key"
        )
        return base64.urlsafe_b64encode(_DEV_KEY[:32])

    def encrypt(self, value: str) -> bytes:
        return self._fernet.encrypt(value.encode("utf-8"))

    def decrypt(self, token: bytes) -> str:
        try:
            return self._fernet.decrypt(token).decode("utf-8")
        except InvalidToken as exc:
            raise ValueError("Failed to decrypt credentials") from exc

    @staticmethod
    def hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()


crypto_service = CryptoService()
