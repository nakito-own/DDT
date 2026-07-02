import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from threading import Lock

from exchangelib import Account

from app.config import settings
from app.db import get_db
from app.services.crypto_service import crypto_service
from app.services.ews_service import EwsConnectionError, ews_service
from app.services.user_service import UserProfile, user_service, user_profile_to_dict


@dataclass
class SessionContext:
    token_hash: str
    email: str
    username: str
    password: str
    ews_server: str
    remember_me: bool
    expires_at: datetime
    user_id: int
    user: UserProfile
    ews_account_id: int | None = None


class SessionService:
    def __init__(self) -> None:
        self._lock = Lock()
        self._memory_sessions: dict[str, SessionContext] = {}
        self._account_cache: dict[str, Account] = {}

    def _expires_at(self, remember_me: bool) -> datetime:
        if remember_me:
            return datetime.utcnow() + timedelta(days=settings.ews_remember_ttl_days)
        return datetime.utcnow() + timedelta(hours=settings.ews_session_ttl_hours)

    def _upsert_account(
        self, email: str, username: str, password: str
    ) -> int:
        username_encrypted = crypto_service.encrypt(username)
        password_encrypted = crypto_service.encrypt(password)

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO ews_accounts
                      (email, username_encrypted, password_encrypted, ews_server)
                    VALUES (%s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                      username_encrypted = VALUES(username_encrypted),
                      password_encrypted = VALUES(password_encrypted),
                      ews_server = VALUES(ews_server),
                      updated_at = CURRENT_TIMESTAMP
                    """,
                    (
                        email,
                        username_encrypted,
                        password_encrypted,
                        settings.ews_server,
                    ),
                )
                cursor.execute(
                    "SELECT id FROM ews_accounts WHERE email = %s",
                    (email,),
                )
                row = cursor.fetchone()
                if not row:
                    raise RuntimeError("Failed to persist EWS account")
                return row["id"]

    def _insert_db_session(
        self, token_hash: str, ews_account_id: int, remember_me: bool, expires_at: datetime
    ) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO app_sessions
                      (token_hash, ews_account_id, remember_me, expires_at)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (token_hash, ews_account_id, remember_me, expires_at),
                )

    def _sync_user_profile(
        self, account: Account, ews_account_id: int
    ) -> UserProfile:
        exchange_profile = ews_service.get_user_profile(account)
        return user_service.upsert_from_exchange(
            email=exchange_profile.email,
            display_name=exchange_profile.display_name,
            job_title=exchange_profile.job_title,
            department=exchange_profile.department,
            phone=exchange_profile.phone,
            office_location=exchange_profile.office_location,
            ews_account_id=ews_account_id,
        )

    def create_session(
        self,
        username: str,
        password: str,
        email: str,
        remember_me: bool,
    ) -> tuple[str, SessionContext]:
        account = ews_service.create_account(username, password, email)
        ews_service.verify_account(account)

        ews_account_id = self._upsert_account(email, username, password)
        user = self._sync_user_profile(account, ews_account_id)

        token = secrets.token_urlsafe(32)
        token_hash = crypto_service.hash_token(token)
        expires_at = self._expires_at(remember_me)

        self._insert_db_session(token_hash, ews_account_id, remember_me, expires_at)

        context = SessionContext(
            token_hash=token_hash,
            email=email,
            username=username,
            password=password,
            ews_server=settings.ews_server,
            remember_me=remember_me,
            expires_at=expires_at,
            ews_account_id=ews_account_id,
            user_id=user.id,
            user=user,
        )

        with self._lock:
            self._memory_sessions[token_hash] = context
            self._account_cache[token_hash] = account

        return token, context

    def _load_db_session(self, token_hash: str) -> SessionContext | None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                      s.remember_me,
                      s.expires_at,
                      a.id AS ews_account_id,
                      a.email,
                      a.username_encrypted,
                      a.password_encrypted,
                      a.ews_server
                    FROM app_sessions s
                    JOIN ews_accounts a ON a.id = s.ews_account_id
                    WHERE s.token_hash = %s
                    """,
                    (token_hash,),
                )
                row = cursor.fetchone()

        if not row:
            return None

        expires_at = row["expires_at"]
        if expires_at < datetime.utcnow():
            self.delete_session(token_hash)
            return None

        user = user_service.get_by_email(row["email"])
        if user is None:
            return None

        return SessionContext(
            token_hash=token_hash,
            email=row["email"],
            username=crypto_service.decrypt(row["username_encrypted"]),
            password=crypto_service.decrypt(row["password_encrypted"]),
            ews_server=row["ews_server"],
            remember_me=bool(row["remember_me"]),
            expires_at=expires_at,
            ews_account_id=row["ews_account_id"],
            user_id=user.id,
            user=user,
        )

    def get_session(self, token: str) -> SessionContext | None:
        token_hash = crypto_service.hash_token(token)
        return self.get_session_by_hash(token_hash)

    def get_session_by_hash(self, token_hash: str) -> SessionContext | None:
        with self._lock:
            context = self._memory_sessions.get(token_hash)

        if context is None:
            context = self._load_db_session(token_hash)
            if context is None:
                return None
            with self._lock:
                self._memory_sessions[token_hash] = context

        if context.expires_at < datetime.utcnow():
            self.delete_session(token_hash)
            return None

        return context

    def get_account(self, context: SessionContext) -> Account:
        with self._lock:
            cached = self._account_cache.get(context.token_hash)
            if cached is not None:
                return cached

        account = ews_service.create_account(
            context.username, context.password, context.email
        )
        ews_service.verify_account(account)

        with self._lock:
            self._account_cache[context.token_hash] = account

        return account

    def refresh_user_profile(self, context: SessionContext) -> UserProfile:
        account = self.get_account(context)
        user = self._sync_user_profile(account, context.ews_account_id or 0)
        context.user = user
        context.user_id = user.id
        with self._lock:
            self._memory_sessions[context.token_hash] = context
        return user

    def delete_session(self, token_hash: str) -> None:
        from app.services.ews_notification_service import ews_notification_service

        ews_notification_service.stop_for_session(token_hash)
        with self._lock:
            self._memory_sessions.pop(token_hash, None)
            self._account_cache.pop(token_hash, None)

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM app_sessions WHERE token_hash = %s",
                    (token_hash,),
                )

    def logout(self, token: str) -> None:
        token_hash = crypto_service.hash_token(token)
        self.delete_session(token_hash)


def session_user_dict(context: SessionContext) -> dict:
    return user_profile_to_dict(context.user)


session_service = SessionService()
