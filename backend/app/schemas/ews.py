from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, model_validator


class UserProfileResponse(BaseModel):
    id: int
    name: str
    email: EmailStr
    display_name: str | None = None
    job_title: str | None = None
    department: str | None = None
    phone: str | None = None
    office_location: str | None = None


class LoginRequest(BaseModel):
    username: str = Field(min_length=1)
    password: str = Field(min_length=1)
    email: EmailStr
    remember_me: bool = False


class LoginResponse(BaseModel):
    session_token: str
    email: EmailStr
    expires_at: datetime
    user: UserProfileResponse


class MeResponse(BaseModel):
    email: EmailStr
    connected: bool
    remember_me: bool
    expires_at: datetime
    user: UserProfileResponse


class MailFoldersResponse(BaseModel):
    inbox: int
    sent: int
    inbox_folder_id: str
    sent_folder_id: str
    folders: list["MailFolderResponse"] = Field(default_factory=list)


class MailFolderResponse(BaseModel):
    id: str
    name: str
    total_count: int = 0
    unread_count: int = 0
    children: list["MailFolderResponse"] = Field(default_factory=list)


MailFolderResponse.model_rebuild()


class MailAttachmentResponse(BaseModel):
    id: str
    name: str
    size: int = 0
    content_type: str = "application/octet-stream"


class MailSummaryResponse(BaseModel):
    id: str
    folder_id: str
    subject: str
    sender: str | None
    datetime_received: datetime | None
    is_read: bool
    preview: str
    has_attachments: bool = False


class MailDetailResponse(MailSummaryResponse):
    body: str
    body_type: str = "text"
    attachments: list[MailAttachmentResponse] = Field(default_factory=list)


class MarkMailReadResponse(BaseModel):
    id: str
    is_read: bool = True


class SendMailRequest(BaseModel):
    to: list[EmailStr] = Field(min_length=1)
    cc: list[EmailStr] = Field(default_factory=list)
    subject: str = Field(min_length=1, max_length=255)
    body: str = Field(min_length=1)


class SendMailResponse(BaseModel):
    status: str = "sent"


class ArchiveMailRequest(BaseModel):
    message_ids: list[str] = Field(min_length=1)
    folder_id: str | None = None


class ArchiveMailResponse(BaseModel):
    archived_ids: list[str]
    errors: dict[str, str] = Field(default_factory=dict)


class CalendarEventResponse(BaseModel):
    id: str
    subject: str
    start: datetime | None
    end: datetime | None
    location: str | None
    organizer: str | None
    my_response_type: str | None = None
    is_meeting: bool = False
    is_response_requested: bool | None = None
    needs_response: bool = False


class CalendarEventResponseRequest(BaseModel):
    response: Literal["accept", "decline", "tentative"]


class CreateCalendarEventRequest(BaseModel):
    subject: str = Field(min_length=1, max_length=255)
    start: datetime
    end: datetime
    location: str | None = Field(default=None, max_length=255)
    body: str | None = None

    @model_validator(mode="after")
    def validate_range(self):
        if self.end <= self.start:
            raise ValueError("end must be after start")
        return self


class ContactResponse(BaseModel):
    id: str
    display_name: str
    emails: list[str]
    phones: list[str]
