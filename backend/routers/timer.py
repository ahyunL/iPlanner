from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.timer import Timer
from models import user as user_model
from pydantic import BaseModel
from datetime import date, timedelta
from utils.auth import get_current_user
from typing import Dict
from schemas.timer import TimerCreate

# 0805 민경 추가.
from services.user_study_service import upsert_user_study_daily


router = APIRouter()





# # 타이머 저장용 스키마
# class TimerCreate(BaseModel):
#     study_date: date
#     total_minutes: int


# 누적이 아닌 여러 세션 생성
@router.post("/")
def add_timer_session(
    data: TimerCreate,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    from datetime import timedelta

    print("수신된 타이머 데이터:", data.dict())

    # 세션 길이 계산: start~end 차이 or fallback to total_minutes
    if data.start_time and data.end_time:
        session_duration = int((data.end_time - data.start_time).total_seconds() / 60)
    else:
        session_duration = data.total_minutes

    # 새로운 Timer row 생성
    timer = Timer(
        user_id=current_user.user_id,
        study_date=data.study_date,
        total_minutes=session_duration,
        start_time=data.start_time,
        end_time=data.end_time
    )
    db.add(timer)
    db.commit()

    # 요약 저장 자동 반영
    upsert_user_study_daily(current_user.user_id, data.study_date, db)

    return {"message": "세션 저장 완료", "session_minutes": session_duration}



# 특정 날짜 공부 시간 조회
from schemas.timer import TimerRead 

@router.get("/timer/{study_date}", response_model=TimerRead)
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
    return timer  # SQLAlchemy 객체 그대로 반환 (TimerRead + orm_mode가 처리)


# 오늘 공부 시간 조회
@router.get("/today")
def get_today_time(
    current_user: user_model.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    today = date.today()
    timers = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date == today
    ).all()
    total_minutes = sum(t.total_minutes for t in timers)
    return {"today_minutes": total_minutes}


# 주간 전체 합계 조회
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

# 주간 요일별 공부 시간 (주차 이동 지원)
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


# 해당 날짜의 모든 공부 세션 불러오기 

from typing import List

@router.get("/sessions/{study_date}", response_model=List[TimerRead])
def get_timer_sessions_by_date(
    study_date: date,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    sessions = db.query(Timer).filter(
        Timer.user_id == current_user.user_id,
        Timer.study_date == study_date
    ).all()

    return sessions


