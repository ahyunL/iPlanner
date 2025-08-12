from pydantic import BaseModel
from datetime import date

class PersonalScheduleCreate(BaseModel):
    title: str
    date: date
    color: str

class PersonalScheduleUpdate(BaseModel):
    title: str
    date: date
    color: str

class PersonalScheduleOut(BaseModel):
    id: int
    title: str
    date: date
    color: str

    class Config:
        orm_mode = True