# services/user_type_service.py
from sqlalchemy.orm import Session
from models.user_type_history import UserTypeHistory
from typing import Optional

import torch
import pickle
import numpy as np
from trained_models.timesnet2 import TimesNet  #  모델 클래스 위치
from fastapi import HTTPException
from models.user_study_daily import UserStudyDaily
from datetime import date, timedelta
from models.user_type_history import UserTypeHistory
from typing import List, Optional

MODEL = None
ENCODERS = None
SCALER = None
DEVICE = None

def compare_latest_user_type_trend(user_id: int, db: Session) -> Optional[str]:
    histories = (
        db.query(UserTypeHistory)
        .filter(UserTypeHistory.user_id == user_id)
        .order_by(UserTypeHistory.week_start_date.desc())
        .limit(2)
        .all()
    )

    if len(histories) < 2:
        return None  # 아직 비교할 데이터 부족

    this_week, last_week = histories[0], histories[1]
    changes = []

    if this_week.sincerity != last_week.sincerity:
        changes.append(f"성실도: {last_week.sincerity} → {this_week.sincerity}")
    if this_week.repetition != last_week.repetition:
        changes.append(f"반복 유형: {last_week.repetition} → {this_week.repetition}")
    if this_week.timeslot != last_week.timeslot:
        changes.append(f"공부 시간대: {last_week.timeslot} → {this_week.timeslot}")

    if not changes:
        return "이번 주 학습 유형은 지난 주와 동일합니다."
    else:
        return "\n".join(changes)




# 설정 클래스
class Configs:
    def __init__(self):
        self.task_name = 'classification'
        self.seq_len = 7
        self.label_len = 0
        self.pred_len = 0
        self.enc_in = 7
        self.d_model = 64
        self.embed = 'timeF'
        self.freq = 'd'
        self.dropout = 0.2
        self.e_layers = 2
        self.top_k = 3
        self.d_ff = 128
        self.num_kernels = 6
        self.num_class = 9



def load_model_and_encoders():
    global MODEL, ENCODERS, SCALER, DEVICE
    if all(v is not None for v in (MODEL, ENCODERS, SCALER, DEVICE)):
        return MODEL, ENCODERS['sincerity'], ENCODERS['repetition'], ENCODERS['timeslot'], SCALER, DEVICE

    config = Configs()
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    MODEL = TimesNet(config).to(DEVICE)

    try:
        MODEL.load_state_dict(torch.load("trained_models/best_model.pth", map_location=DEVICE))
        MODEL.eval()
    except Exception:
        raise HTTPException(status_code=500, detail="모델 파일을 불러오지 못했습니다.")

    try:
        with open("trained_models/label_encoders.pkl", "rb") as f:
            ENCODERS = pickle.load(f)
    except Exception:
        raise HTTPException(status_code=500, detail="인코더 파일을 불러오지 못했습니다.")

    try:
        import joblib
        SCALER = joblib.load("trained_models/scaler.pkl")
    except Exception:
        raise HTTPException(status_code=500, detail="스케일러 파일을 불러오지 못했습니다.")

    return MODEL, ENCODERS['sincerity'], ENCODERS['repetition'], ENCODERS['timeslot'], SCALER, DEVICE




def predict_user_type(sample_data: list[list[float]]):
    if len(sample_data) != 7 or any(len(row) != 7 for row in sample_data):
        raise HTTPException(status_code=400, detail="입력 데이터는 7일치 * 7개 feature가 필요합니다.")

    # 스케일러까지 함께 받기
    model, le1, le2, le3, scaler, device = load_model_and_encoders()

    # (7,7) → (1,7,7)
    arr = np.array(sample_data, dtype=np.float32).reshape(1, 7, 7)

    # 스케일 적용: (1,7,7) → (7,7) → (49,7) 에 transform → 다시 (1,7,7)
    flat = arr.reshape(-1, 7)            # (49, 7)
    flat_scaled = scaler.transform(flat) # (49, 7)
    arr_scaled = flat_scaled.reshape(1, 7, 7)

    X_input = torch.tensor(arr_scaled, dtype=torch.float32).to(device)
    x_mark = torch.ones((1, 7), dtype=torch.float32).to(device)

    with torch.no_grad():
        pred = model(X_input, x_mark, None, None)  # (1, 9)
        out1, out2, out3 = torch.split(pred, [3, 2, 4], dim=1)

        pred1 = le1.inverse_transform(torch.argmax(out1, dim=1).cpu().numpy())[0]
        pred2 = le2.inverse_transform(torch.argmax(out2, dim=1).cpu().numpy())[0]
        pred3 = le3.inverse_transform(torch.argmax(out3, dim=1).cpu().numpy())[0]

    return {
        "성실도": pred1,
        "반복형": pred2,
        "시간대": pred3
    }



def auto_predict_and_save_user_type(user_id: int, db: Session):
    today = date.today()

    # 최근 7일(과거→현재 순서)
    days: List[date] = [today - timedelta(days=i) for i in range(6, -1, -1)]

    # DB에서 최근 7일 가져오기
    records = (
        db.query(UserStudyDaily)
        .filter(UserStudyDaily.user_id == user_id, UserStudyDaily.study_date.in_(days))
        .all()
    )
    by_date = {r.study_date: r for r in records}

    # ▶ feature 순서 맞춰 벡터 생성
    def to_vec(r: UserStudyDaily) -> List[float]:
        return [
            float(r.total_minutes),       # 총학습시간(분)
            float(r.morning_minutes),     # 오전(분)
            float(r.afternoon_minutes),   # 오후(분)
            float(r.evening_minutes),     # 저녁(분)
            float(r.night_minutes),       # 심야(분)
            float(r.repetition),          # 반복횟수
            float(r.daily_achievement),   # 일일달성률(%)
        ]

    # 원시 입력 + 결측 마스크
    input_data: List[Optional[List[float]]] = []
    is_missing: List[bool] = []
    for d in days:
        if d in by_date:
            input_data.append(to_vec(by_date[d]))
            is_missing.append(False)
        else:
            input_data.append(None)
            is_missing.append(True)

    # 평균으로 결측 채우기
    observed = [v for v in input_data if v is not None]

    def colwise_mean(rows: List[List[float]]) -> List[float]:
        if not rows:
            return [0.0] * 7
        n, m = len(rows), len(rows[0])
        return [sum(r[j] for r in rows) / n for j in range(m)]

    base_mean = colwise_mean(observed)
    for i in range(len(input_data)):
        if input_data[i] is None:
            input_data[i] = base_mean.copy()

    # 결측일 집계
    missing_days = sum(is_missing)

    # 모델 예측
    prediction = predict_user_type(input_data)

    # 이번 주 월요일
    week_start = today - timedelta(days=today.weekday())

    # 중복 저장 방지
    existing = (
        db.query(UserTypeHistory)
        .filter(
            UserTypeHistory.user_id == user_id,
            UserTypeHistory.week_start_date == week_start,
        )
        .first()
    )
    if existing:
        existing.sincerity = prediction["성실도"]
        existing.repetition = prediction["반복형"]
        existing.timeslot = prediction["시간대"]
        db.commit()
    else:
        new_entry = UserTypeHistory(
            user_id=user_id,
            week_start_date=week_start,
            sincerity=prediction["성실도"],
            repetition=prediction["반복형"],
            timeslot=prediction["시간대"],
        )
        db.add(new_entry)
        db.commit()

    return {
        "message": "자동 예측 및 저장 완료",
        "prediction": prediction,
        "missing_days": missing_days,
        "filled_input_preview": input_data,
    }

