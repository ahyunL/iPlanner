

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.user import User
from models.user_study_daily import UserStudyDaily
from utils.auth import get_current_user
from schemas import user_study_schema as schemas
from datetime import date
from services.user_study_service import upsert_user_study_daily



router = APIRouter()


# 1. 요약 자동 저장 API (중복 시 덮어쓰기)
@router.post("/study-daily/auto")
def generate_and_save_study_summary(
    date: date,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    record = upsert_user_study_daily(current_user.user_id, date, db)

    return {
        "message": f"{date} 요약 저장 완료",
        "data": {
            "study_date": record.study_date,
            "total_minutes": record.total_minutes,
            "morning_minutes": record.morning_minutes,
            "afternoon_minutes": record.afternoon_minutes,
            "evening_minutes": record.evening_minutes,
            "night_minutes": record.night_minutes,
            "repetition": record.repetition,
            "daily_achievement": record.daily_achievement,
        },
    }


# 2. 달성률 업데이트 API (중복 시 덮어쓰기)
@router.post("/study-daily/achievement", response_model=schemas.UserStudyDailyOut)
def upsert_daily_achievement(
    data: schemas.UserStudyAchievementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    print(f"👤 current_user.id = {current_user.user_id}")
    print(f"📆 요청된 날짜 = {data.study_date}")
    print(f"📊 달성률 = {data.daily_achievement}")

    record = db.query(UserStudyDaily).filter(
        UserStudyDaily.user_id == current_user.user_id,
        UserStudyDaily.study_date == data.study_date
    ).first()

    if record:
        print("✅ 기존 기록 있음 → 업데이트 진행")
        record.daily_achievement = data.daily_achievement
    else:
        print("🆕 기존 기록 없음 → 새로 생성")
        record = UserStudyDaily(
            user_id=current_user.user_id,
            study_date=data.study_date,
            daily_achievement=data.daily_achievement,
        )
        db.add(record)

    db.commit()
    db.refresh(record)
    return record


