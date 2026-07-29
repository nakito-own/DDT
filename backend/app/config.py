from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    port: int = 3000
    db_host: str = "localhost"
    db_port: int = 3306
    db_user: str = "ddt_user"
    db_password: str = "ddt_password"
    db_name: str = "ddt"

    ews_server: str = "owa.mos.ru"
    ews_auth_type: str = "NTLM"
    ews_service_endpoint: str = ""
    ews_verify_max_attempts: int = 3
    ews_verify_retry_delay_seconds: float = 1.0
    ews_credentials_key: str = ""
    ews_session_ttl_hours: int = 24
    ews_remember_ttl_days: int = 30
    ews_timezone: str = "Europe/Moscow"

    ews_notification_mode: Literal["streaming", "pull"] = "pull"
    ews_notification_stream_timeout: int = 1
    ews_notification_poll_interval: int = 15
    ews_notification_pull_timeout: int = 10


settings = Settings()
