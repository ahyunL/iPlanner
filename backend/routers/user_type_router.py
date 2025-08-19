

# routers/user_type_router.py
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from db import get_db
from models.user_type_history import UserTypeHistory
from models.user import User
from utils.auth import get_current_user

from services.user_type_service import (
    compare_latest_user_type_trend,
    build_week_7x7_from_db,
    predict_user_type,
    auto_predict_and_save_user_type_with_fallback,
)

from schemas.user_type_schema import UserTypeInput, UserTypeSampleInput
from trained_models.runtime import summarize_week
from services.gpt_feedback_service import generate_feedback_prompt, request_feedback_from_gpt

router = APIRouter()  # main.py에서 prefix="/user-type"로 mount

DAYS_KR = ["월", "화", "수", "목", "금", "토", "일"]

"""
/user-type/save         → 수동 저장
/user-type/trend        → 전주 대비 비교
/user-type/feedback     → GPT 피드백 생성(주기성 지표 포함)
/user-type/predict      → 수동 예측
/user-type/auto-predict → 자동 예측+저장(부족 시 폴백)
"""

# 1) 학습유형 저장
@router.post("/save")
def save_user_type_history(
    data: UserTypeInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    new_entry = UserTypeHistory(
        user_id=current_user.user_id,
        week_start_date=data.week_start_date,
        sincerity=data.sincerity,
        repetition=data.repetition,
        timeslot=data.timeslot,
    )
    db.add(new_entry)
    db.commit()
    return {"message": "User type saved successfully"}

# 2) 전주 대비 추세 비교
@router.get("/trend")
def get_user_type_trend(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trend = compare_latest_user_type_trend(current_user.user_id, db)
    if trend is None:
        return {"message": "비교할 학습유형 데이터가 아직 충분하지 않습니다."}
    return {"trend": trend}

# 3) GPT 피드백 생성 (주기성 요약 + 요일-날짜 라벨 + 자연 결측 안내)
@router.get("/feedback")
def get_user_type_feedback(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    uth = (
        db.query(UserTypeHistory)
        .filter(UserTypeHistory.user_id == current_user.user_id)
        .order_by(UserTypeHistory.week_start_date.desc())
        .first()
    )
    if not uth:
        raise HTTPException(status_code=400, detail="피드백을 생성할 학습유형 데이터가 없습니다.")

    trend = compare_latest_user_type_trend(current_user.user_id, db) \
        or "이번 주와 지난 주의 유형 변화는 크지 않습니다."

    week_start = uth.week_start_date
    mat7x7 = build_week_7x7_from_db(db, current_user.user_id, week_start)
    summary = summarize_week(mat7x7)  # missing_days, raw_pattern, weekend_share, peak_day, burstiness ...

    # ✅ 요일-날짜 라벨 제공 (예: "2025-08-18(월)")
    day_labels = [
        f"{(week_start + timedelta(days=i)).isoformat()}({DAYS_KR[i]})"
        for i in range(7)
    ]

    this_week = {
        "sincerity": uth.sincerity,
        "repetition": uth.repetition,
        "timeslot": uth.timeslot,
        "week_start_date": week_start.isoformat(),
        "day_labels": day_labels,  # ← 추가
        **summary,
    }

    prompt = generate_feedback_prompt(this_week=this_week, trend_summary=trend)
    feedback_text = request_feedback_from_gpt(prompt)
    return {"feedback": feedback_text}

# 4) 수동 예측
@router.post("/predict")
def predict_user_type_endpoint(
    data: UserTypeSampleInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return predict_user_type(data.sample_data)

# 5) 자동 예측 + 저장 (부족 시 폴백)
@router.post("/auto-predict")
def auto_predict_user_type(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return auto_predict_and_save_user_type_with_fallback(
        current_user.user_id, db,
        minutes_threshold=60,
        active_days_threshold=2,
    )
