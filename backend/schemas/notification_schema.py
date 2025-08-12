from pydantic import BaseModel, Field, ConfigDict
from typing import List
from datetime import datetime

class NotificationOut(BaseModel):
    id: int = Field(alias="notification_id")
    title: str
    body: str
    read: bool = Field(alias="is_read")
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
    )

class NotificationCreate(BaseModel):
    title: str
    body: str

class IdsIn(BaseModel):
    ids: List[int]