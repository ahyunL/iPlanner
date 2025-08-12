# routers/user_study_router.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.user import User
from models.user_study_daily import UserStudyDaily
from utils.auth import get_current_user
from schemas import user_study_schema as schemas
from datetime import date, timedelta
from services.user_study_service import upsert_user_study_daily
from typing import List

router = APIRouter()



# 1) 특정 날짜 요약을 계산하고 저장(있으면 덮어쓰기)
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



# 2) 일일 달성률 저장/업데이트
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

# 3) 최근 7일(월→일 순) 자동 집계 후 반환
@router.get("/study-daily/last7", response_model=List[schemas.UserStudyDailyOut])
def get_last7(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    today = date.today()
    days = [today - timedelta(days=i) for i in range(6, -1, -1)]  # 오래된→최근
    # 저장(집계) 보정
    records = []
    for d in days:
        rec = upsert_user_study_daily(current_user.user_id, d, db)
        records.append(rec)
    # Pydantic 모델로 자동 직렬화
    return records