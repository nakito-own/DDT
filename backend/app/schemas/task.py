from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.models.task import TaskPriority


class TaskTypeResponse(BaseModel):
    id: int
    name: str


class TaskLinkPayload(BaseModel):
    url: str = Field(min_length=1, max_length=2048)
    title: str | None = Field(default=None, max_length=255)


class TaskLinkResponse(TaskLinkPayload):
    id: int


class TaskCommentResponse(BaseModel):
    id: int
    author_id: int | None
    text: str
    created_at: datetime


class CreateTaskCommentRequest(BaseModel):
    text: str = Field(min_length=1, max_length=10000)

    @field_validator("text")
    @classmethod
    def normalize_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Comment text must not be empty")
        return value


class TaskFieldValuePayload(BaseModel):
    field_id: int
    value: Any = None


class TaskNotificationsPayload(BaseModel):
    notify_assigned: bool = True
    notify_updated: bool = True
    notify_comment: bool = True
    notify_deleted: bool = True
    deadline_reminder_hours: int | None = Field(default=None, ge=1, le=24 * 90)


class TaskFieldValueResponse(BaseModel):
    field_id: int
    name: str
    field_type: str
    list_multiple: bool = False
    options: list[str] = Field(default_factory=list)
    value: Any = None


class TaskComponentResponse(BaseModel):
    id: int
    name: str


class TaskNotificationsResponse(BaseModel):
    notify_assigned: bool = True
    notify_updated: bool = True
    notify_comment: bool = True
    notify_deleted: bool = True
    deadline_reminder_hours: int | None = None


class TaskRefResponse(BaseModel):
    id: int
    key: str
    title: str
    status: str


class TaskResponse(BaseModel):
    id: int
    key: str
    title: str
    status: str
    status_name: str = ""
    status_category: str = "open"
    type_id: int | None = None
    type: TaskTypeResponse | None = None
    description: str = ""
    executor_id: int | None = None
    author_id: int | None = None
    responsible_id: int | None = None
    owner_id: int | None = None
    space_id: int | None = None
    space_key: str | None = None
    parent_id: int | None = None
    time_set: datetime
    time_start: datetime | None = None
    time_end: datetime | None = None
    deadline: datetime | None = None
    priority: TaskPriority | None = None
    deleted: bool = False
    archive: bool = False
    links: list[TaskLinkResponse] = Field(default_factory=list)
    comments: list[TaskCommentResponse] = Field(default_factory=list)
    parent: TaskRefResponse | None = None
    children: list[TaskRefResponse] = Field(default_factory=list)
    field_values: list[TaskFieldValueResponse] = Field(default_factory=list)
    components: list[TaskComponentResponse] = Field(default_factory=list)
    notifications: TaskNotificationsResponse = Field(
        default_factory=TaskNotificationsResponse
    )
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CreateTaskRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    status: str | None = None
    type_id: int | None = None
    description: str = ""
    executor_id: int | None = None
    responsible_id: int | None = None
    time_set: datetime | None = None
    time_start: datetime | None = None
    time_end: datetime | None = None
    deadline: datetime | None = None
    priority: TaskPriority | None = None
    links: list[TaskLinkPayload] = Field(default_factory=list)
    initial_comment: str | None = Field(default=None, max_length=10000)
    parent_key: str | None = Field(default=None, max_length=191)
    child_keys: list[str] = Field(default_factory=list)
    field_values: list[TaskFieldValuePayload] | None = None
    component_ids: list[int] | None = None
    notifications: TaskNotificationsPayload | None = None

    @field_validator("initial_comment")
    @classmethod
    def normalize_initial_comment(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("parent_key")
    @classmethod
    def normalize_parent_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None


class UpdateTaskRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    status: str | None = None
    type_id: int | None = None
    description: str | None = None
    executor_id: int | None = None
    author_id: int | None = None
    responsible_id: int | None = None
    time_set: datetime | None = None
    time_start: datetime | None = None
    time_end: datetime | None = None
    deadline: datetime | None = None
    priority: TaskPriority | None = None
    links: list[TaskLinkPayload] | None = None
    parent_key: str | None = Field(default=None, max_length=191)
    child_keys: list[str] | None = None
    archive: bool | None = None
    field_values: list[TaskFieldValuePayload] | None = None
    component_ids: list[int] | None = None
    notifications: TaskNotificationsPayload | None = None

    @field_validator("parent_key")
    @classmethod
    def normalize_parent_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None


class UpdateTaskStatusRequest(BaseModel):
    status: str = Field(min_length=1, max_length=50)
