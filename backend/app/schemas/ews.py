from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserProfileResponse(BaseModel):
    id: int
    name: str
    email: EmailStr
    username: str | None = None
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
