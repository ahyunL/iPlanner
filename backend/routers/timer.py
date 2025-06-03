from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.timer import Timer
from models import user as user_model
from pydantic import BaseModel
from datetime import date, timedelta
from utils.auth import get_current_user  # ✅ 로그인 유저 가져오기

router = APIRouter()

# ✅ 타이머 생성 요청용 스키마
class TimerCreate(BaseModel):
    study_date: date
    total_minutes: int

# ✅ 공부 시간 저장 (누적 또는 갱신)
@router.post("/timer")
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
        timer.total_minutes = data.total_minutes  # 또는 += data.total_minutes
    else:
        timer = Timer(
            user_id=current_user.user_id,
            study_date=data.study_date,
            total_minutes=data.total_minutes
        )
        db.add(timer)

    db.commit()
    return {"message": "Timer recorded", "minutes": timer.total_minutes}

# ✅ 특정 날짜의 공부 시간 조회
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
@router.get("/timer/today")
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

# ✅ 주간 공부 시간 조회
@router.get("/timer/weekly")
def get_weekly_time(
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
