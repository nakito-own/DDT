from datetime import datetime

from pydantic import BaseModel


class SpaceResponse(BaseModel):
    id: int
    name: str
    created_at: datetime
