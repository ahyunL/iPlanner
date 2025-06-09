from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.timer import Timer
from models import user as user_model
from pydantic import BaseModel
from datetime import date, timedelta
from utils.auth import get_current_user
from typing import Dict

router = APIRouter()

# ✅ 타이머 저장용 스키마
class TimerCreate(BaseModel):
    study_date: date
    total_minutes: int

# ✅ 공부 시간 저장 (추가 또는 갱신)
@router.post("/")
def add_or_update_timer(
    data: TimerCreate,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    timer = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date == data.study_date
    ).first()

    if timer:
        timer.total_minutes = data.total_minutes
    else:
        timer = Timer(
            user_id=current_user.user_id,
            study_date=data.study_date,
            total_minutes=data.total_minutes
        )
        db.add(timer)

    db.commit()
    return {"message": "Timer recorded", "minutes": timer.total_minutes}

# ✅ 특정 날짜 공부 시간 조회
@router.get("/timer/{study_date}")
def get_timer(
    study_date: date,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    timer = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date == study_date
    ).first()
    if not timer:
        raise HTTPException(status_code=404, detail="No timer found")
    return {"total_minutes": timer.total_minutes}

# ✅ 오늘 공부 시간 조회
@router.get("/today")
def get_today_time(
    current_user: user_model.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    today = date.today()
    timer = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date == today
    ).first()
    return {"today_minutes": timer.total_minutes if timer else 0}

# ✅ 주간 전체 합계 조회
@router.get("/weekly")
def get_weekly_total_time(
    current_user: user_model.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    today = date.today()
    start_week = today - timedelta(days=today.weekday())
    end_week = start_week + timedelta(days=6)

    total = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date >= start_week,
        Timer.study_date <= end_week
    ).all()

    weekly_minutes = sum(t.total_minutes for t in total)
    return {"weekly_minutes": weekly_minutes}

# ✅ 주간 요일별 공부 시간 (주차 이동 지원)
@router.get("/weekly-by-day")
def get_weekly_minutes_by_day(
    week_offset: int = 0,
    current_user: user_model.User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, int]:
    today = date.today()
    start_of_week = today - timedelta(days=today.weekday()) + timedelta(weeks=week_offset)
    end_of_week = start_of_week + timedelta(days=6)

    results = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date >= start_of_week,
        Timer.study_date <= end_of_week
    ).all()

    study_by_day = {day: 0 for day in ['월', '화', '수', '목', '금', '토', '일']}
    for entry in results:
        weekday_name = ['월', '화', '수', '목', '금', '토', '일'][entry.study_date.weekday()]
        study_by_day[weekday_name] += entry.total_minutes

    return study_by_day
