from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

from app.models.task import TaskPriority

StatusCategory = Literal["open", "active", "closed"]
FieldType = Literal["text", "number", "date", "list", "user", "checkbox"]


class QueueStatusPayload(BaseModel):
    id: int | None = None
    key: str = ""
    name: str = Field(min_length=1, max_length=100)
    category: StatusCategory
    sort_order: int = 0
    is_system: bool = False


class QueueTypePayload(BaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=100)
    sort_order: int = 0


class QueueFieldPayload(BaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=100)
    field_type: FieldType
    list_multiple: bool = False
    options: list[str] = Field(default_factory=list)
    default_value: Any = None
    sort_order: int = 0

    @field_validator("options")
    @classmethod
    def clean_options(cls, value: list[str]) -> list[str]:
        cleaned = []
        seen: set[str] = set()
        for item in value:
            text = item.strip()
            if not text or text in seen:
                continue
            seen.add(text)
            cleaned.append(text[:100])
        return cleaned


class QueueComponentPayload(BaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=100)
    sort_order: int = 0
    is_default: bool = False


class QueueSettingsWrite(BaseModel):
    default_status_key: str = Field(min_length=1, max_length=50)
    default_type_name: str = Field(min_length=1, max_length=100)
    default_deadline_days: int | None = Field(default=None, ge=0, le=3650)
    default_priority: TaskPriority | None = None
    notify_assigned: bool = True
    notify_updated: bool = True
    notify_comment: bool = True
    notify_deleted: bool = True
    deadline_reminder_hours: int | None = Field(default=None, ge=1, le=24 * 90)
    statuses: list[QueueStatusPayload] = Field(min_length=1)
    types: list[QueueTypePayload] = Field(min_length=1)
    fields: list[QueueFieldPayload] = Field(default_factory=list)
    components: list[QueueComponentPayload] = Field(default_factory=list)


class QueueStatusResponse(BaseModel):
    id: int
    key: str
    name: str
    category: StatusCategory
    sort_order: int
    is_system: bool


class QueueTypeResponse(BaseModel):
    id: int
    name: str
    sort_order: int


class QueueFieldResponse(BaseModel):
    id: int
    name: str
    field_type: FieldType
    list_multiple: bool
    options: list[str] = Field(default_factory=list)
    default_value: Any = None
    sort_order: int


class QueueComponentResponse(BaseModel):
    id: int
    name: str
    sort_order: int
    is_default: bool = False


class QueueSettingsResponse(BaseModel):
    id: int
    space_id: int | None = None
    owner_id: int | None = None
    default_status_key: str
    default_type_id: int | None = None
    default_type_name: str | None = None
    default_deadline_days: int | None = None
    default_priority: TaskPriority | None = None
    notify_assigned: bool = True
    notify_updated: bool = True
    notify_comment: bool = True
    notify_deleted: bool = True
    deadline_reminder_hours: int | None = None
    statuses: list[QueueStatusResponse]
    types: list[QueueTypeResponse]
    fields: list[QueueFieldResponse]
    components: list[QueueComponentResponse]
    default_component_ids: list[int] = Field(default_factory=list)
