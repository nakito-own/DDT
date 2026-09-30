from datetime import datetime

from pydantic import BaseModel


class SpaceResponse(BaseModel):
    id: int
    name: str
    space_key: str
    created_at: datetime
