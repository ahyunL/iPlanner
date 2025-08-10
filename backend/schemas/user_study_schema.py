from pydantic import BaseModel
from datetime import date

class UserStudyDailyInput(BaseModel):
    study_date: date
    total_minutes: int
    morning_minutes: int
    afternoon_minutes: int
    evening_minutes: int
    night_minutes: int
    repetition: int
    daily_achievement: int



class UserStudyAchievementCreate(BaseModel):
    study_date: date
    daily_achievement: int


class UserStudyDailyOut(BaseModel):
    user_id: int               # 추가
    study_date: date
    total_minutes: int
    morning_minutes: int
    afternoon_minutes: int
    evening_minutes: int
    night_minutes: int
    repetition: int
    daily_achievement: int

    class Config:
        from_attributes = True

