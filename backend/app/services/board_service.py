import json
import uuid

from app.db import get_db

# LONGTEXT can hold more; this cap keeps one request from filling the disk.
_MAX_PROJECT_BYTES = 8 * 1024 * 1024

_SUMMARY_COLUMNS = """
id, title, author_id, author_name, created_at, updated_at
"""


class BoardNotFoundError(Exception):
    pass


class BoardPayloadError(Exception):
    def __init__(self, detail: str) -> None:
        self.detail = detail
        super().__init__(detail)


class BoardService:
    def list_boards(self) -> list[dict]:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS}
                    FROM boards
                    ORDER BY updated_at DESC, created_at DESC
                    """
                )
                return list(cursor.fetchall())

    def get_board(self, board_id: str) -> dict | None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS}, project_json
                    FROM boards
                    WHERE id = %s
                    """,
                    (board_id,),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return _with_project(row)

    def create_board(self, *, title: str, author_id: int, author_name: str) -> dict:
        board_id = str(uuid.uuid4())
        name = title.strip()
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO boards (id, title, author_id, author_name)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (board_id, name, author_id, author_name),
                )
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS}, project_json
                    FROM boards
                    WHERE id = %s
                    """,
                    (board_id,),
                )
                row = cursor.fetchone()
        return _with_project(row)

    def update_board(
        self,
        board_id: str,
        *,
        title: str | None = None,
        project: dict | None = None,
        project_set: bool = False,
    ) -> dict:
        if title is None and not project_set:
            raise BoardPayloadError("Nothing to update")

        assignments = ["updated_at = CURRENT_TIMESTAMP"]
        params: list = []
        if title is not None:
            assignments.append("title = %s")
            params.append(title.strip())
        if project_set:
            assignments.append("project_json = %s")
            params.append(_dump_project(project))
        params.append(board_id)

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT id FROM boards WHERE id = %s", (board_id,))
                if cursor.fetchone() is None:
                    raise BoardNotFoundError
                cursor.execute(
                    f"""
                    UPDATE boards
                    SET {", ".join(assignments)}
                    WHERE id = %s
                    """,
                    params,
                )
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS}, project_json
                    FROM boards
                    WHERE id = %s
                    """,
                    (board_id,),
                )
                row = cursor.fetchone()
        if row is None:
            raise BoardNotFoundError
        return _with_project(row)

    def delete_board(self, board_id: str) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("DELETE FROM boards WHERE id = %s", (board_id,))
                if cursor.rowcount == 0:
                    raise BoardNotFoundError


def _dump_project(project: dict | None) -> str | None:
    if project is None:
        return None
    try:
        encoded = json.dumps(project, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError) as exc:
        raise BoardPayloadError("Board project must be JSON") from exc
    if len(encoded.encode("utf-8")) > _MAX_PROJECT_BYTES:
        raise BoardPayloadError("Board project is too large")
    return encoded


def _with_project(row: dict) -> dict:
    raw = row.get("project_json")
    project = None
    if isinstance(raw, str) and raw:
        project = json.loads(raw)
    mapped = {key: value for key, value in row.items() if key != "project_json"}
    mapped["project"] = project
    return mapped


board_service = BoardService()
