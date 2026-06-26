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
    ews_credentials_key: str = ""
    ews_session_ttl_hours: int = 24
    ews_remember_ttl_days: int = 30
    ews_timezone: str = "Europe/Moscow"


settings = Settings()
