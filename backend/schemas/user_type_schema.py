# schemas/user_type_schema.py
from pydantic import BaseModel
from datetime import date
from typing import List

class UserTypeInput(BaseModel):
    week_start_date: date
    sincerity: str
    repetition: str
    timeslot: str


class UserTypeSampleInput(BaseModel):
    sample_data: List[List[float]]  # 7 x 7