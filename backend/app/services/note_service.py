import uuid

from pymysql.err import IntegrityError

from app.db import get_db

_MAX_BODY_BYTES = 1_000_000

_SUMMARY_COLUMNS = """
id, parent_id, kind, title, author_id, author_name, created_at, updated_at
"""


class NoteNotFoundError(Exception):
    pass


class NotePayloadError(Exception):
    def __init__(self, detail: str) -> None:
        self.detail = detail
        super().__init__(detail)


class NoteService:
    def list_notes(self) -> list[dict]:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS},
                           CASE
                             WHEN kind = 'note' THEN LEFT(body, 240)
                             ELSE NULL
                           END AS preview
                    FROM notes
                    ORDER BY updated_at DESC, created_at DESC
                    """
                )
                return [_summary(row) for row in cursor.fetchall()]

    def get_note(self, note_id: str) -> dict | None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT {_SUMMARY_COLUMNS}, body
                    FROM notes
                    WHERE id = %s
                    """,
                    (note_id,),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return _detail(row)

    def create_note(
        self,
        *,
        title: str,
        kind: str,
        parent_id: str | None,
        author_id: int,
        author_name: str,
    ) -> dict:
        note_id = str(uuid.uuid4())
        name = _clean_title(title)
        with get_db() as conn:
            with conn.cursor() as cursor:
                _assert_parent(cursor, parent_id, node_id=None, kind=kind)
                try:
                    cursor.execute(
                        """
                        INSERT INTO notes (
                          id, parent_id, kind, title, body, author_id, author_name
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            note_id,
                            parent_id,
                            kind,
                            name,
                            "" if kind == "note" else None,
                            author_id,
                            author_name,
                        ),
                    )
                except IntegrityError as exc:
                    raise NotePayloadError("Не удалось создать заметку") from exc
                return _read_detail(cursor, note_id)

    def update_note(
        self,
        note_id: str,
        *,
        title: str | None = None,
        body: str | None = None,
        body_set: bool = False,
        parent_id: str | None = None,
        parent_set: bool = False,
    ) -> dict:
        if title is None and not body_set and not parent_set:
            raise NotePayloadError("Нечего сохранять")

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id, kind FROM notes WHERE id = %s",
                    (note_id,),
                )
                current = cursor.fetchone()
                if current is None:
                    raise NoteNotFoundError

                assignments: list[str] = []
                params: list = []
                if title is not None:
                    assignments.append("title = %s")
                    params.append(_clean_title(title))
                if body_set:
                    if current["kind"] != "note":
                        raise NotePayloadError("У папки нет текста")
                    assignments.append("body = %s")
                    params.append(_clean_body(body))
                if parent_set:
                    _assert_parent(
                        cursor,
                        parent_id,
                        node_id=note_id,
                        kind=current["kind"],
                    )
                    assignments.append("parent_id = %s")
                    params.append(parent_id)
                params.append(note_id)
                cursor.execute(
                    f"""
                    UPDATE notes
                    SET {", ".join(assignments)}
                    WHERE id = %s
                    """,
                    params,
                )
                return _read_detail(cursor, note_id)

    def delete_note(self, note_id: str) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("DELETE FROM notes WHERE id = %s", (note_id,))
                if cursor.rowcount == 0:
                    raise NoteNotFoundError


def _read_detail(cursor, note_id: str) -> dict:
    cursor.execute(
        f"""
        SELECT {_SUMMARY_COLUMNS}, body
        FROM notes
        WHERE id = %s
        """,
        (note_id,),
    )
    row = cursor.fetchone()
    if row is None:
        raise NoteNotFoundError
    return _detail(row)


def _summary(row: dict) -> dict:
    preview = row.get("preview")
    if not isinstance(preview, str) or preview == "":
        preview = None
    return {
        "id": row["id"],
        "parent_id": row["parent_id"],
        "kind": row["kind"],
        "title": row["title"],
        "preview": preview,
        "author_id": row["author_id"],
        "author_name": row["author_name"] or "",
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _detail(row: dict) -> dict:
    kind = row["kind"]
    body = row.get("body")
    text = body if isinstance(body, str) else ""
    mapped = _summary(
        {
            **row,
            "preview": text[:240] if kind == "note" and text else None,
        }
    )
    mapped["body"] = text if kind == "note" else None
    return mapped


def _clean_title(title: str) -> str:
    name = title.strip()
    if not name:
        raise NotePayloadError("Введите название")
    if len(name) > 255:
        raise NotePayloadError("Название слишком длинное")
    return name


def _clean_body(body: str | None) -> str:
    text = body or ""
    if len(text.encode("utf-8")) > _MAX_BODY_BYTES:
        raise NotePayloadError("Текст заметки слишком большой")
    return text


def _assert_parent(cursor, parent_id: str | None, *, node_id: str | None, kind: str) -> None:
    if not parent_id:
        return
    if node_id is not None and parent_id == node_id:
        raise NotePayloadError("Нельзя вложить папку саму в себя")

    cursor.execute("SELECT id, kind FROM notes WHERE id = %s", (parent_id,))
    parent = cursor.fetchone()
    if parent is None or parent["kind"] != "folder":
        raise NotePayloadError("Родитель должен быть папкой")
    if node_id is None or kind != "folder":
        return

    current = parent_id
    seen: set[str] = set()
    while current is not None:
        if current == node_id:
            raise NotePayloadError("Нельзя переместить папку внутрь самой себя")
        if current in seen:
            return
        seen.add(current)
        cursor.execute("SELECT parent_id FROM notes WHERE id = %s", (current,))
        ancestor = cursor.fetchone()
        current = None if ancestor is None else ancestor["parent_id"]


note_service = NoteService()
