from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class NoteSummary(BaseModel):
    id: str
    parent_id: str | None = None
    kind: Literal["folder", "note"]
    title: str
    preview: str | None = None
    author_id: int | None = None
    author_name: str
    created_at: datetime
    updated_at: datetime


class NoteResponse(NoteSummary):
    body: str | None = None


class CreateNoteRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    kind: Literal["folder", "note"] = "note"
    parent_id: str | None = None


class UpdateNoteRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    body: str | None = None
    parent_id: str | None = None
