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
    ews_connect_timeout_seconds: float = 15.0
    ews_read_timeout_seconds: float = 60.0
    ews_pool_maxsize: int = 8
    ews_thread_pool_size: int = 12
    ews_max_concurrent_operations: int = 6
    ews_max_queued_per_session: int = 6
    ews_server_busy_default_backoff_seconds: float = 30.0
    ews_credentials_key: str = ""
    ews_session_ttl_hours: int = 24
    ews_remember_ttl_days: int = 30
    # How long a loaded session is served from memory before a cheap DB check.
    session_cache_ttl_seconds: int = 120
    ews_refresh_interval_hours: int = 12
    ews_refresh_check_seconds: int = 300
    ews_timezone: str = "Europe/Moscow"

    ews_notification_mode: Literal["streaming", "pull"] = "pull"
    ews_notification_stream_timeout: int = 1
    ews_notification_poll_interval: int = 15
    ews_notification_pull_timeout: int = 10

    google_sheets_spreadsheet_id: str = "1BNbGKCTTia0DQiM01AP1FYQe0paywTen56AQgCpz-tw"
    google_sheets_sheet_name: str = "Заявки"
    google_sheets_credentials_path: str = ""
    google_sheets_credentials_json: str = ""
    google_sheets_cache_ttl_seconds: int = 60
    google_sheets_timeout_seconds: float = 30.0

    dtw_base_url: str = "https://dtwapi.mos.ru"
    dtw_login: str = ""
    dtw_password: str = ""
    dtw_dataset_id: int = 28107
    dtw_page_size: int = 1000
    dtw_timeout_seconds: float = 120.0
    dtw_offset_param: str = "offset"
    dtw_limit_param: str = "limit"

    avatar_dir: str = ""

    analytics_timezone: str = "Europe/Moscow"
    analytics_itsm_base_url: str = "https://sc-tech-solutions.itsm.mos.ru/requests/"

    # all — один процесс (локальный запуск). api / mail / analytics — отдельные
    # процессы в compose, у почты и аналитики свой потолок CPU.
    app_role: Literal["all", "api", "mail", "analytics"] = "all"
    dashboard_queue_timeout_seconds: float = 5.0
    krr_query_timeout_ms: int = 20000


settings = Settings()
