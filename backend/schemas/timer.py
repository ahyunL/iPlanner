from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional

# 공부 시간 생성 요청용 (POST /timer)
class TimerCreate(BaseModel):
    study_date: date
    total_minutes: int
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

# 공부 시간 조회 응답용
class TimerRead(BaseModel):
    timer_id: int
    user_id: int
    study_date: date
    total_minutes: int
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

    class Config:
        orm_mode = True