from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.task import TaskPriority, TaskStatus


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


class TaskResponse(BaseModel):
    id: int
    title: str
    status: TaskStatus
    type_id: int | None = None
    type: TaskTypeResponse | None = None
    description: str = ""
    executor_id: int | None = None
    author_id: int | None = None
    responsible_id: int | None = None
    owner_id: int
    space_id: int | None = None
    time_set: datetime
    time_start: datetime | None = None
    time_end: datetime | None = None
    deadline: datetime | None = None
    priority: TaskPriority | None = None
    links: list[TaskLinkResponse] = Field(default_factory=list)
    comments: list[TaskCommentResponse] = Field(default_factory=list)
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CreateTaskRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    status: TaskStatus = TaskStatus.TODO
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

    @field_validator("initial_comment")
    @classmethod
    def normalize_initial_comment(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None


class UpdateTaskRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    status: TaskStatus | None = None
    type_id: int | None = None
    description: str | None = None
    executor_id: int | None = None
    responsible_id: int | None = None
    time_set: datetime | None = None
    time_start: datetime | None = None
    time_end: datetime | None = None
    deadline: datetime | None = None
    priority: TaskPriority | None = None
    links: list[TaskLinkPayload] | None = None


class UpdateTaskStatusRequest(BaseModel):
    status: TaskStatus
