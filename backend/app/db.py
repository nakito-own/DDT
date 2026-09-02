from contextlib import contextmanager

import pymysql
from pymysql.cursors import DictCursor

from app.config import settings


def _connect():
    return pymysql.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
        database=settings.db_name,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=True,
    )


@contextmanager
def get_db():
    conn = _connect()
    try:
        yield conn
    finally:
        conn.close()
