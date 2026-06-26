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

    def _fetch_task_row(self, cursor, task_id: int, owner_id: int):
        cursor.execute(
            """
            SELECT
              t.*,
              tt.id AS type_ref_id,
              tt.name AS type_name,
              tt.created_at AS type_created_at
            FROM tasks t
            LEFT JOIN task_types tt ON tt.id = t.type_id
            WHERE t.id = %s AND t.owner_id = %s
            """,
            (task_id, owner_id),
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
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                      t.*,
                      tt.id AS type_ref_id,
                      tt.name AS type_name,
                      tt.created_at AS type_created_at
                    FROM tasks t
                    LEFT JOIN task_types tt ON tt.id = t.type_id
                    WHERE t.owner_id = %s
                    ORDER BY t.updated_at DESC, t.id DESC
                    """,
                    (owner_id,),
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
        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(cursor, task_id, owner_id)
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

    def create_task(
        self, owner_id: int, author_id: int, payload: CreateTaskRequest
    ) -> dict:
        time_set = payload.time_set or datetime.utcnow()

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO tasks (
                      title, status, type_id, description,
                      executor_id, author_id, responsible_id, owner_id,
                      time_set, time_start, time_end, deadline, priority
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
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

        return self.get_task(task_id, owner_id)

    def update_task(
        self, task_id: int, owner_id: int, payload: UpdateTaskRequest
    ) -> dict:
        updates: dict = payload.model_dump(exclude_unset=True)
        links = updates.pop("links", None)

        if not updates and links is None:
            return self.get_task(task_id, owner_id)

        if "status" in updates and updates["status"] is not None:
            updates["status"] = updates["status"].value
        if "priority" in updates and updates["priority"] is not None:
            updates["priority"] = updates["priority"].value

        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(cursor, task_id, owner_id)
                if not row:
                    raise TaskNotFoundError

                if updates:
                    set_clause = ", ".join(f"{column} = %s" for column in updates)
                    values = list(updates.values()) + [task_id, owner_id]
                    cursor.execute(
                        f"""
                        UPDATE tasks
                        SET {set_clause}
                        WHERE id = %s AND owner_id = %s
                        """,
                        values,
                    )

                if links is not None:
                    self._replace_links(cursor, task_id, links)

        return self.get_task(task_id, owner_id)

    def delete_task(self, task_id: int, owner_id: int) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM tasks WHERE id = %s AND owner_id = %s",
                    (task_id, owner_id),
                )
                if cursor.rowcount == 0:
                    raise TaskNotFoundError


task_service = TaskService()


def task_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Task not found",
    )
