from datetime import datetime

from fastapi import HTTPException, status

from app.db import get_db
from app.models.task import map_task_comment_row, map_task_link_row, map_task_row, map_task_type_row
from app.schemas.task import CreateTaskRequest, TaskLinkPayload, UpdateTaskRequest


class TaskNotFoundError(Exception):
    pass


class TaskService:
    def list_task_types(self) -> list[dict]:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id, name, created_at FROM task_types ORDER BY id"
                )
                rows = cursor.fetchall()
        return [map_task_type_row(row) for row in rows]

    def _fetch_links(self, cursor, task_ids: list[int]) -> dict[int, list[dict]]:
        if not task_ids:
            return {}

        placeholders = ", ".join(["%s"] * len(task_ids))
        cursor.execute(
            f"""
            SELECT id, task_id, url, title
            FROM task_links
            WHERE task_id IN ({placeholders})
            ORDER BY id
            """,
            task_ids,
        )
        rows = cursor.fetchall()
        grouped: dict[int, list[dict]] = {task_id: [] for task_id in task_ids}
        for row in rows:
            grouped[row["task_id"]].append(map_task_link_row(row))
        return grouped

    def _fetch_comments(self, cursor, task_ids: list[int]) -> dict[int, list[dict]]:
        if not task_ids:
            return {}

        placeholders = ", ".join(["%s"] * len(task_ids))
        cursor.execute(
            f"""
            SELECT id, task_id, author_id, text, created_at
            FROM task_comments
            WHERE task_id IN ({placeholders})
            ORDER BY id
            """,
            task_ids,
        )
        rows = cursor.fetchall()
        grouped: dict[int, list[dict]] = {task_id: [] for task_id in task_ids}
        for row in rows:
            grouped[row["task_id"]].append(map_task_comment_row(row))
        return grouped

    def _fetch_task_row(
        self,
        cursor,
        task_id: int,
        owner_id: int,
        *,
        space_id: int | None = None,
    ):
        scope_column = "space_id" if space_id is not None else "owner_id"
        scope_id = space_id if space_id is not None else owner_id
        personal_filter = "" if space_id is not None else "AND t.space_id IS NULL"
        cursor.execute(
            f"""
            SELECT
              t.*,
              tt.id AS type_ref_id,
              tt.name AS type_name,
              tt.created_at AS type_created_at
            FROM tasks t
            LEFT JOIN task_types tt ON tt.id = t.type_id
            WHERE t.id = %s AND t.{scope_column} = %s {personal_filter}
            """,
            (task_id, scope_id),
        )
        return cursor.fetchone()

    def _serialize_task(self, row, *, links=None, comments=None) -> dict:
        task_type = None
        if row.get("type_ref_id"):
            task_type = map_task_type_row(
                {
                    "id": row["type_ref_id"],
                    "name": row["type_name"],
                    "created_at": row["type_created_at"],
                }
            )

        return map_task_row(
            row,
            type_=task_type,
            links=links or [],
            comments=comments or [],
        )

    def list_tasks(self, owner_id: int) -> list[dict]:
        return self._list_tasks("owner_id", owner_id)

    def list_space_tasks(self, space_id: int) -> list[dict]:
        return self._list_tasks("space_id", space_id)

    def _list_tasks(self, scope_column: str, scope_id: int) -> list[dict]:
        personal_filter = (
            "AND t.space_id IS NULL" if scope_column == "owner_id" else ""
        )
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT
                      t.*,
                      tt.id AS type_ref_id,
                      tt.name AS type_name,
                      tt.created_at AS type_created_at
                    FROM tasks t
                    LEFT JOIN task_types tt ON tt.id = t.type_id
                    WHERE t.{scope_column} = %s {personal_filter}
                    ORDER BY t.updated_at DESC, t.id DESC
                    """,
                    (scope_id,),
                )
                rows = cursor.fetchall()
                task_ids = [row["id"] for row in rows]
                links = self._fetch_links(cursor, task_ids)
                comments = self._fetch_comments(cursor, task_ids)

        return [
            self._serialize_task(
                row,
                links=links.get(row["id"], []),
                comments=comments.get(row["id"], []),
            )
            for row in rows
        ]

    def get_task(self, task_id: int, owner_id: int) -> dict:
        return self._get_task(task_id, owner_id)

    def get_space_task(self, task_id: int, space_id: int) -> dict:
        return self._get_task(task_id, owner_id=0, space_id=space_id)

    def _get_task(
        self,
        task_id: int,
        owner_id: int,
        *,
        space_id: int | None = None,
    ) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(
                    cursor,
                    task_id,
                    owner_id,
                    space_id=space_id,
                )
                if not row:
                    raise TaskNotFoundError
                links = self._fetch_links(cursor, [task_id]).get(task_id, [])
                comments = self._fetch_comments(cursor, [task_id]).get(task_id, [])

        return self._serialize_task(row, links=links, comments=comments)

    def _replace_links(self, cursor, task_id: int, links: list[TaskLinkPayload]) -> None:
        cursor.execute("DELETE FROM task_links WHERE task_id = %s", (task_id,))
        for link in links:
            cursor.execute(
                """
                INSERT INTO task_links (task_id, url, title)
                VALUES (%s, %s, %s)
                """,
                (task_id, link.url, link.title),
            )

    def _insert_comment(
        self, cursor, task_id: int, author_id: int, text: str
    ) -> int:
        cursor.execute(
            """
            INSERT INTO task_comments (task_id, author_id, text)
            VALUES (%s, %s, %s)
            """,
            (task_id, author_id, text),
        )
        return cursor.lastrowid

    def create_task(
        self,
        owner_id: int,
        author_id: int,
        payload: CreateTaskRequest,
        *,
        space_id: int | None = None,
    ) -> dict:
        time_set = payload.time_set or datetime.utcnow()

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO tasks (
                      title, status, type_id, description,
                      executor_id, author_id, responsible_id, owner_id,
                      space_id, time_set, time_start, time_end, deadline, priority
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        payload.title,
                        payload.status.value,
                        payload.type_id,
                        payload.description,
                        payload.executor_id,
                        author_id,
                        payload.responsible_id,
                        owner_id,
                        space_id,
                        time_set,
                        payload.time_start,
                        payload.time_end,
                        payload.deadline,
                        payload.priority.value if payload.priority else None,
                    ),
                )
                task_id = cursor.lastrowid
                if payload.links:
                    self._replace_links(cursor, task_id, payload.links)
                if payload.initial_comment:
                    self._insert_comment(
                        cursor, task_id, author_id, payload.initial_comment
                    )

        return self._get_task(
            task_id,
            owner_id,
            space_id=space_id,
        )

    def add_comment(
        self,
        task_id: int,
        owner_id: int,
        author_id: int,
        text: str,
        *,
        space_id: int | None = None,
    ) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(
                    cursor,
                    task_id,
                    owner_id,
                    space_id=space_id,
                )
                if not row:
                    raise TaskNotFoundError

                comment_id = self._insert_comment(
                    cursor, task_id, author_id, text
                )
                cursor.execute(
                    """
                    SELECT id, task_id, author_id, text, created_at
                    FROM task_comments
                    WHERE id = %s
                    """,
                    (comment_id,),
                )
                comment = cursor.fetchone()

        return map_task_comment_row(comment)

    def update_task(
        self,
        task_id: int,
        owner_id: int,
        payload: UpdateTaskRequest,
        *,
        space_id: int | None = None,
    ) -> dict:
        updates: dict = payload.model_dump(exclude_unset=True)
        links = updates.pop("links", None)

        if not updates and links is None:
            return self._get_task(task_id, owner_id, space_id=space_id)

        if "status" in updates and updates["status"] is not None:
            updates["status"] = updates["status"].value
        if "priority" in updates and updates["priority"] is not None:
            updates["priority"] = updates["priority"].value

        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(
                    cursor,
                    task_id,
                    owner_id,
                    space_id=space_id,
                )
                if not row:
                    raise TaskNotFoundError

                if updates:
                    set_clause = ", ".join(f"{column} = %s" for column in updates)
                    scope_column = (
                        "space_id" if space_id is not None else "owner_id"
                    )
                    scope_id = space_id if space_id is not None else owner_id
                    personal_filter = (
                        "" if space_id is not None else "AND space_id IS NULL"
                    )
                    values = list(updates.values()) + [task_id, scope_id]
                    cursor.execute(
                        f"""
                        UPDATE tasks
                        SET {set_clause}
                        WHERE id = %s AND {scope_column} = %s {personal_filter}
                        """,
                        values,
                    )

                if links is not None:
                    self._replace_links(cursor, task_id, links)

        return self._get_task(task_id, owner_id, space_id=space_id)

    def delete_task(
        self,
        task_id: int,
        owner_id: int,
        *,
        space_id: int | None = None,
    ) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                scope_column = "space_id" if space_id is not None else "owner_id"
                scope_id = space_id if space_id is not None else owner_id
                personal_filter = (
                    "" if space_id is not None else "AND space_id IS NULL"
                )
                cursor.execute(
                    f"""
                    DELETE FROM tasks
                    WHERE id = %s AND {scope_column} = %s {personal_filter}
                    """,
                    (task_id, scope_id),
                )
                if cursor.rowcount == 0:
                    raise TaskNotFoundError


task_service = TaskService()


def task_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Task not found",
    )
