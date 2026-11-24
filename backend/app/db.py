from contextlib import contextmanager

import pymysql
from pymysql.cursors import DictCursor

from app.config import settings


def _connect(*, read_timeout: int = 30, write_timeout: int = 30):
    return pymysql.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
        database=settings.db_name,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=True,
        connect_timeout=5,
        read_timeout=read_timeout,
        write_timeout=write_timeout,
    )


@contextmanager
def get_db(
    *,
    read_timeout: int = 30,
    write_timeout: int = 30,
    max_execution_time_ms: int | None = None,
):
    conn = _connect(read_timeout=read_timeout, write_timeout=write_timeout)
    try:
        if max_execution_time_ms is not None:
            limit = max(1, int(max_execution_time_ms))
            with conn.cursor() as cursor:
                cursor.execute(f"SET SESSION MAX_EXECUTION_TIME = {limit}")
        yield conn
    finally:
        conn.close()
