from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class BoardSummary(BaseModel):
    id: str
    title: str
    author_id: int | None = None
    author_name: str
    created_at: datetime
    updated_at: datetime


class BoardResponse(BoardSummary):
    project: dict[str, Any] | None = None


class CreateBoardRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)


class UpdateBoardRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    project: dict[str, Any] | None = None
