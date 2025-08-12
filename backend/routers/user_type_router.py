from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.user_type_history import UserTypeHistory
from models.user import User
from schemas.user_type_schema import UserTypeInput
from utils.auth import get_current_user
from services.user_type_service import compare_latest_user_type_trend
from services.gpt_feedback_service import generate_feedback_prompt, request_feedback_from_gpt
from services.user_type_service import auto_predict_and_save_user_type_with_fallback

router = APIRouter()

'''
/user-type/save → 수동 저장

/user-type/trend → 전주 대비 비교

/user-type/feedback → GPT 피드백 생성

/user-type/predict → 수동 예측

/user-type/auto-predict" → 자동으로 7일치 데이터를 불러와서 예측하고 user_type_history에 자동 저장하는 API
'''

#  1. 학습유형 저장
@router.post("/save")
def save_user_type_history(
    data: UserTypeInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
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


#  2. 전주 대비 추세 비교
@router.get("/trend")
def get_user_type_trend(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    trend = compare_latest_user_type_trend(current_user.user_id, db)
    if trend is None:
        return {"message": "비교할 학습유형 데이터가 아직 충분하지 않습니다."}
    return {"trend": trend}


#  3. GPT 피드백 생성
@router.get("/feedback")
def get_user_type_feedback(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    trend = compare_latest_user_type_trend(current_user.user_id, db)
    if not trend:
        raise HTTPException(status_code=400, detail="비교할 학습유형 데이터가 부족합니다.")

    this_week = (
        db.query(UserTypeHistory)
        .filter(UserTypeHistory.user_id == current_user.user_id)
        .order_by(UserTypeHistory.week_start_date.desc())
        .first()
    )

    prompt = generate_feedback_prompt(this_week, trend)
    feedback = request_feedback_from_gpt(prompt)

    return {"feedback": feedback}


from schemas.user_type_schema import UserTypeSampleInput
from services.user_type_service import predict_user_type

@router.post("/predict")
def predict_user_type_endpoint(
    data: UserTypeSampleInput,  # sample_data: List[List[float]] (7일치 * 7개 feature)
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return predict_user_type(data.sample_data)


from services.user_type_service import auto_predict_and_save_user_type

# @router.post("/auto-predict")
# def auto_predict_user_type(
#     db: Session = Depends(get_db),
#     current_user: User = Depends(get_current_user)
# ):
#     return auto_predict_and_save_user_type(current_user.user_id, db)


@router.post("/auto-predict")
def auto_predict_user_type(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 필요하면 임계값 조정 가능: minutes_threshold=90, active_days_threshold=2 등
    return auto_predict_and_save_user_type_with_fallback(
        current_user.user_id, db,
        minutes_threshold=60,
        active_days_threshold=2,
    )