from datetime import datetime

from fastapi import HTTPException, status
from pymysql.err import IntegrityError

from app.db import get_db
from app.models.task import map_task_comment_row, map_task_link_row, map_task_row, map_task_type_row
from app.schemas.task import CreateTaskRequest, TaskLinkPayload, UpdateTaskRequest
from app.services.task_key import build_task_key, normalize_user_key_prefix


TASK_SELECT = """
SELECT
  t.*,
  tt.id AS type_ref_id,
  tt.name AS type_name,
  tt.created_at AS type_created_at,
  s.space_key AS space_key
FROM tasks t
LEFT JOIN task_types tt ON tt.id = t.type_id
LEFT JOIN spaces s ON s.id = t.space_id
"""


class TaskNotFoundError(Exception):
    pass


class TaskRelationError(Exception):
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

    def _map_ref(self, row) -> dict:
        return {
            "id": row["id"],
            "key": row["task_key"],
            "title": row["title"],
            "status": row["status"],
        }

    def _fetch_relations(
        self, cursor, rows: list[dict]
    ) -> tuple[dict[int, dict], dict[int, list[dict]]]:
        if not rows:
            return {}, {}

        task_ids = [row["id"] for row in rows]
        parent_ids = [
            row["parent_id"] for row in rows if row.get("parent_id") is not None
        ]
        placeholders = ", ".join(["%s"] * len(task_ids))
        cursor.execute(
            f"""
            SELECT id, parent_id, task_key, title, status
            FROM tasks
            WHERE parent_id IN ({placeholders})
            ORDER BY id
            """,
            task_ids,
        )
        child_rows = cursor.fetchall()
        children: dict[int, list[dict]] = {task_id: [] for task_id in task_ids}
        extra_ids: list[int] = []
        for child in child_rows:
            parent_id = child["parent_id"]
            children.setdefault(parent_id, []).append(self._map_ref(child))
            extra_ids.append(child["id"])

        ref_ids = list({*task_ids, *parent_ids, *extra_ids})
        parents: dict[int, dict] = {}
        if ref_ids:
            ref_placeholders = ", ".join(["%s"] * len(ref_ids))
            cursor.execute(
                f"""
                SELECT id, task_key, title, status
                FROM tasks
                WHERE id IN ({ref_placeholders})
                """,
                ref_ids,
            )
            for row in cursor.fetchall():
                parents[row["id"]] = self._map_ref(row)

        return parents, children

    def _fetch_task_row(
        self,
        cursor,
        task_id: int | None = None,
        *,
        owner_id: int | None = None,
        space_id: int | None = None,
        task_ref: str | None = None,
    ):
        clauses = []
        params: list = []
        if task_ref is not None:
            if task_ref.isdigit():
                clauses.append("t.id = %s")
                params.append(int(task_ref))
            else:
                clauses.append("t.task_key = %s")
                params.append(task_ref)
        elif task_id is not None:
            clauses.append("t.id = %s")
            params.append(task_id)
        else:
            return None

        if space_id is not None:
            clauses.append("t.space_id = %s")
            params.append(space_id)
        elif owner_id is not None:
            clauses.append("t.owner_id = %s")
            clauses.append("t.space_id IS NULL")
            params.append(owner_id)

        cursor.execute(
            f"{TASK_SELECT} WHERE {' AND '.join(clauses)}",
            params,
        )
        return cursor.fetchone()

    def _serialize_task(
        self,
        row,
        *,
        links=None,
        comments=None,
        parent=None,
        children=None,
    ) -> dict:
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
            parent=parent,
            children=children or [],
        )

    def _serialize_rows(self, cursor, rows: list[dict]) -> list[dict]:
        task_ids = [row["id"] for row in rows]
        links = self._fetch_links(cursor, task_ids)
        comments = self._fetch_comments(cursor, task_ids)
        parents, children = self._fetch_relations(cursor, rows)
        return [
            self._serialize_task(
                row,
                links=links.get(row["id"], []),
                comments=comments.get(row["id"], []),
                parent=parents.get(row["parent_id"]) if row.get("parent_id") else None,
                children=children.get(row["id"], []),
            )
            for row in rows
        ]

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
                    {TASK_SELECT}
                    WHERE t.{scope_column} = %s {personal_filter}
                    ORDER BY t.updated_at DESC, t.id DESC
                    """,
                    (scope_id,),
                )
                rows = cursor.fetchall()
                return self._serialize_rows(cursor, rows)

    def get_task(self, task_id: int, owner_id: int) -> dict:
        return self._get_task(task_id, owner_id)

    def get_space_task(self, task_id: int, space_id: int) -> dict:
        return self._get_task(task_id, owner_id=0, space_id=space_id)

    def get_task_by_ref(self, task_ref: str, user_id: int) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(cursor, task_ref=task_ref)
                if not row or not self._can_access(row, user_id):
                    raise TaskNotFoundError
                return self._serialize_rows(cursor, [row])[0]

    def _can_access(self, row, user_id: int) -> bool:
        if row.get("space_id") is not None:
            return True
        return row.get("owner_id") == user_id

    def _can_mutate(self, row, user_id: int) -> bool:
        return self._can_access(row, user_id)

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
                    owner_id=None if space_id is not None else owner_id,
                    space_id=space_id,
                )
                if not row:
                    raise TaskNotFoundError
                return self._serialize_rows(cursor, [row])[0]

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

    def _next_task_number(self, cursor, prefix: str) -> int:
        cursor.execute(
            """
            INSERT INTO task_key_counters (key_prefix, last_number)
            VALUES (%s, 1)
            ON DUPLICATE KEY UPDATE last_number = last_number + 1
            """,
            (prefix,),
        )
        cursor.execute(
            "SELECT last_number FROM task_key_counters WHERE key_prefix = %s",
            (prefix,),
        )
        row = cursor.fetchone()
        return int(row["last_number"])

    def _prefix_for_task(
        self,
        cursor,
        *,
        owner_id: int,
        space_id: int | None,
        username: str | None,
    ) -> str:
        if space_id is not None:
            cursor.execute(
                "SELECT space_key FROM spaces WHERE id = %s",
                (space_id,),
            )
            space = cursor.fetchone()
            if not space or not space["space_key"]:
                raise TaskNotFoundError
            return space["space_key"]

        cursor.execute(
            "SELECT username FROM users WHERE id = %s",
            (owner_id,),
        )
        user = cursor.fetchone()
        stored = (user or {}).get("username") if user else None
        login_prefix = normalize_user_key_prefix(username or "")
        if login_prefix != "user":
            return login_prefix
        if stored:
            return stored
        prefix = login_prefix
        if prefix == "user":
            prefix = f"user{owner_id}"
        return prefix

    def _assign_task_key(
        self,
        cursor,
        task_id: int,
        *,
        owner_id: int,
        space_id: int | None,
        username: str | None,
    ) -> None:
        prefix = self._prefix_for_task(
            cursor,
            owner_id=owner_id,
            space_id=space_id,
            username=username,
        )
        number = self._next_task_number(cursor, prefix)
        cursor.execute(
            """
            UPDATE tasks
            SET task_key = %s, key_prefix = %s, task_number = %s
            WHERE id = %s
            """,
            (build_task_key(prefix, number), prefix, number, task_id),
        )

    def _same_scope(self, left, right) -> bool:
        if left.get("space_id") is not None or right.get("space_id") is not None:
            return left.get("space_id") == right.get("space_id")
        return left.get("owner_id") == right.get("owner_id")

    def _load_by_ref(self, cursor, task_ref: str):
        row = self._fetch_task_row(cursor, task_ref=task_ref)
        if not row:
            raise TaskRelationError(f"Связанная задача {task_ref} не найдена")
        return row

    def _would_cycle(self, cursor, task_id: int, parent_id: int) -> bool:
        current = parent_id
        seen: set[int] = set()
        while current is not None:
            if current == task_id:
                return True
            if current in seen:
                return True
            seen.add(current)
            cursor.execute(
                "SELECT parent_id FROM tasks WHERE id = %s",
                (current,),
            )
            row = cursor.fetchone()
            current = row["parent_id"] if row else None
        return False

    def _set_parent(self, cursor, task_row, parent_key: str | None) -> None:
        task_id = task_row["id"]
        if not parent_key:
            cursor.execute(
                "UPDATE tasks SET parent_id = NULL WHERE id = %s",
                (task_id,),
            )
            return

        parent = self._load_by_ref(cursor, parent_key)
        if parent["id"] == task_id:
            raise TaskRelationError("Задача не может быть родителем самой себя")
        if not self._same_scope(task_row, parent):
            raise TaskRelationError(
                "Родительская задача должна быть в том же пространстве или личном списке"
            )
        if self._would_cycle(cursor, task_id, parent["id"]):
            raise TaskRelationError("Нельзя создать циклическую иерархию задач")
        cursor.execute(
            "UPDATE tasks SET parent_id = %s WHERE id = %s",
            (parent["id"], task_id),
        )

    def _set_children(self, cursor, task_row, child_keys: list[str]) -> None:
        task_id = task_row["id"]
        desired_ids: list[int] = []
        for key in child_keys:
            child = self._load_by_ref(cursor, key)
            if child["id"] == task_id:
                raise TaskRelationError("Задача не может быть дочерней для самой себя")
            if not self._same_scope(task_row, child):
                raise TaskRelationError(
                    "Дочерние задачи должны быть в том же пространстве или личном списке"
                )
            if self._would_cycle(cursor, child["id"], task_id):
                raise TaskRelationError("Нельзя создать циклическую иерархию задач")
            desired_ids.append(child["id"])

        cursor.execute(
            "SELECT id FROM tasks WHERE parent_id = %s",
            (task_id,),
        )
        current_ids = {row["id"] for row in cursor.fetchall()}
        desired = set(desired_ids)
        to_detach = current_ids - desired
        if to_detach:
            placeholders = ", ".join(["%s"] * len(to_detach))
            cursor.execute(
                f"UPDATE tasks SET parent_id = NULL WHERE id IN ({placeholders})",
                list(to_detach),
            )
        for child_id in desired_ids:
            cursor.execute(
                "UPDATE tasks SET parent_id = %s WHERE id = %s",
                (task_id, child_id),
            )

    def create_task(
        self,
        owner_id: int,
        author_id: int,
        payload: CreateTaskRequest,
        *,
        space_id: int | None = None,
        username: str | None = None,
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
                try:
                    self._assign_task_key(
                        cursor,
                        task_id,
                        owner_id=owner_id,
                        space_id=space_id,
                        username=username,
                    )
                except IntegrityError as exc:
                    raise TaskRelationError(
                        "Не удалось выделить ключ задачи, попробуйте ещё раз"
                    ) from exc
                if payload.links:
                    self._replace_links(cursor, task_id, payload.links)
                if payload.initial_comment:
                    self._insert_comment(
                        cursor, task_id, author_id, payload.initial_comment
                    )
                row = self._fetch_task_row(cursor, task_id)
                if payload.parent_key:
                    self._set_parent(cursor, row, payload.parent_key)
                    row = self._fetch_task_row(cursor, task_id)
                if payload.child_keys:
                    self._set_children(cursor, row, payload.child_keys)

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
                    owner_id=None if space_id is not None else owner_id,
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

    def add_comment_by_ref(
        self, task_ref: str, user_id: int, text: str
    ) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(cursor, task_ref=task_ref)
                if not row or not self._can_mutate(row, user_id):
                    raise TaskNotFoundError
                comment_id = self._insert_comment(cursor, row["id"], user_id, text)
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
        return self._update_task_row(
            payload,
            user_id=owner_id,
            task_id=task_id,
            space_id=space_id,
            owner_id=None if space_id is not None else owner_id,
        )

    def update_task_by_ref(
        self, task_ref: str, user_id: int, payload: UpdateTaskRequest
    ) -> dict:
        return self._update_task_row(payload, user_id=user_id, task_ref=task_ref)

    def _update_task_row(
        self,
        payload: UpdateTaskRequest,
        *,
        user_id: int,
        task_id: int | None = None,
        task_ref: str | None = None,
        owner_id: int | None = None,
        space_id: int | None = None,
    ) -> dict:
        updates: dict = payload.model_dump(
            exclude_unset=True,
            exclude={"parent_key", "child_keys"},
        )
        links = updates.pop("links", None)
        parent_specified = "parent_key" in payload.model_fields_set
        children_specified = "child_keys" in payload.model_fields_set

        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(
                    cursor,
                    task_id,
                    owner_id=owner_id,
                    space_id=space_id,
                    task_ref=task_ref,
                )
                if not row or (
                    task_ref is not None and not self._can_mutate(row, user_id)
                ):
                    raise TaskNotFoundError

                resolved_id = row["id"]
                if not updates and links is None and not parent_specified and not children_specified:
                    return self._serialize_rows(cursor, [row])[0]

                if "status" in updates and updates["status"] is not None:
                    updates["status"] = updates["status"].value
                if "priority" in updates and updates["priority"] is not None:
                    updates["priority"] = updates["priority"].value

                if updates:
                    set_clause = ", ".join(f"{column} = %s" for column in updates)
                    values = list(updates.values()) + [resolved_id]
                    cursor.execute(
                        f"UPDATE tasks SET {set_clause} WHERE id = %s",
                        values,
                    )

                if links is not None:
                    self._replace_links(cursor, resolved_id, links)
                if parent_specified:
                    self._set_parent(cursor, row, payload.parent_key)
                    row = self._fetch_task_row(cursor, resolved_id)
                if children_specified:
                    self._set_children(cursor, row, payload.child_keys or [])

                return self._serialize_rows(
                    cursor, [self._fetch_task_row(cursor, resolved_id)]
                )[0]

    def delete_task(
        self,
        task_id: int,
        owner_id: int,
        *,
        space_id: int | None = None,
    ) -> None:
        self._delete_task_row(
            user_id=owner_id,
            task_id=task_id,
            owner_id=None if space_id is not None else owner_id,
            space_id=space_id,
        )

    def delete_task_by_ref(self, task_ref: str, user_id: int) -> None:
        self._delete_task_row(user_id=user_id, task_ref=task_ref)

    def _delete_task_row(
        self,
        *,
        user_id: int,
        task_id: int | None = None,
        task_ref: str | None = None,
        owner_id: int | None = None,
        space_id: int | None = None,
    ) -> None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                row = self._fetch_task_row(
                    cursor,
                    task_id,
                    owner_id=owner_id,
                    space_id=space_id,
                    task_ref=task_ref,
                )
                if not row or (
                    task_ref is not None and not self._can_mutate(row, user_id)
                ):
                    raise TaskNotFoundError
                cursor.execute("DELETE FROM tasks WHERE id = %s", (row["id"],))
                if cursor.rowcount == 0:
                    raise TaskNotFoundError


task_service = TaskService()


def task_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Task not found",
    )


def task_relation_error(exc: TaskRelationError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=str(exc),
    )
