from enum import StrEnum


class TaskStatus(StrEnum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    DONE = "done"


class TaskPriority(StrEnum):
    INSIGNIFICANT = "insignificant"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    BLOCKER = "blocker"


TASK_STATUSES = list(TaskStatus)
TASK_PRIORITIES = list(TaskPriority)


def map_task_type_row(row):
    if not row:
        return None

    return {
        "id": row["id"],
        "name": row["name"],
        "created_at": row["created_at"],
    }


def map_task_link_row(row):
    return {
        "id": row["id"],
        "url": row["url"],
        "title": row["title"],
    }


def map_task_comment_row(row):
    return {
        "id": row["id"],
        "author_id": row["author_id"],
        "text": row["text"],
        "created_at": row["created_at"],
    }


def map_task_row(row, *, type_=None, links=None, comments=None):
    return {
        "id": row["id"],
        "title": row["title"],
        "status": row["status"],
        "type_id": row["type_id"],
        "type": type_,
        "description": row["description"],
        "executor_id": row["executor_id"],
        "author_id": row["author_id"],
        "responsible_id": row["responsible_id"],
        "owner_id": row["owner_id"],
        "space_id": row.get("space_id"),
        "time_set": row["time_set"],
        "time_start": row["time_start"],
        "time_end": row["time_end"],
        "deadline": row["deadline"],
        "priority": row["priority"],
        "links": links or [],
        "comments": comments or [],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }
