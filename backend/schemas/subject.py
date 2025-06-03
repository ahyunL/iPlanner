from pydantic import BaseModel
from datetime import datetime

class SubjectCreate(BaseModel):
    field: str           # 시험 분야
    test_name: str       # 시험 이름
    test_date: datetime  # 시험 날짜
    start_date: datetime
    end_date: datetime
