# services/user_type_service.py
from __future__ import annotations

from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import date, timedelta
from fastapi import HTTPException

from models.user_study_daily import UserStudyDaily
from models.user_type_history import UserTypeHistory

# ✅ XGBoost 러너(3-헤드) + 주간 요약
from trained_models.runtime import predict_user_type_xgb, summarize_week


# ─────────────────────────────────────────────────────────────
# 최근 2주 비교 텍스트
# ─────────────────────────────────────────────────────────────
def compare_latest_user_type_trend(user_id: int, db: Session) -> Optional[str]:
    histories = (
        db.query(UserTypeHistory)
        .filter(UserTypeHistory.user_id == user_id)
        .order_by(UserTypeHistory.week_start_date.desc())
        .limit(2)
        .all()
    )
    if len(histories) < 2:
        return None

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
    return "\n".join(changes)


# ─────────────────────────────────────────────────────────────
# DB → 7×7 매트릭스 생성 (총/오전/오후/저녁/심야/반복/달성률)
# ─────────────────────────────────────────────────────────────
def _week_dates(week_start: date) -> List[date]:
    return [week_start + timedelta(days=i) for i in range(7)]

def _row_from_daily(r: UserStudyDaily) -> List[float]:
    return [
        float(r.total_minutes or 0),     # 총학습시간(분)
        float(r.morning_minutes or 0),   # 오전(분)
        float(r.afternoon_minutes or 0), # 오후(분)
        float(r.evening_minutes or 0),   # 저녁(분)
        float(r.night_minutes or 0),     # 심야(분)
        float(r.repetition or 0),        # 반복횟수
        float(r.daily_achievement or 0), # 일일달성률(%)
    ]

def build_week_7x7_from_db(db: Session, user_id: int, week_start: date) -> List[List[float]]:
    days = _week_dates(week_start)
    rows = (
        db.query(UserStudyDaily)
        .filter(
            UserStudyDaily.user_id == user_id,
            UserStudyDaily.study_date >= days[0],
            UserStudyDaily.study_date <= days[-1],
        )
        .all()
    )
    by_date = {r.study_date: r for r in rows}

    mat: List[List[float]] = []
    for d in days:
        r = by_date.get(d)
        mat.append(_row_from_daily(r) if r else [0.0] * 7)
    return mat


# ─────────────────────────────────────────────────────────────
# 예측 API (입력 7×7 직접 전달)
# ─────────────────────────────────────────────────────────────
def predict_user_type(sample_data: List[List[float]]):
    """
    입력: 7일 × 7특징(총/오전/오후/저녁/심야/반복/달성률)
    출력 키: '성실도','반복형','시간대'
    """
    if len(sample_data) != 7 or any(len(row) != 7 for row in sample_data):
        raise HTTPException(status_code=400, detail="입력 데이터는 7일치 × 7개 feature가 필요합니다.")

    # Δ + 요일(sin/cos) 전처리는 runtime 내부에서 처리됨
    p = predict_user_type_xgb(sample_data)
    return {"성실도": p["성실도"], "반복형": p["반복형"], "시간대": p["시간대"]}


# ─────────────────────────────────────────────────────────────
# 자동 예측 + 저장 (주간 패턴 반환)
# ─────────────────────────────────────────────────────────────
def auto_predict_and_save_user_type(user_id: int, db: Session):
    today = date.today()
    week_start = today - timedelta(days=today.weekday())  # 월요일 시작
    mat7x7 = build_week_7x7_from_db(db, user_id, week_start)

    # 주간 요약
    summary = summarize_week(mat7x7)
    missing_days = summary.get("missing_days", 0)

    # 모델 예측
    p = predict_user_type_xgb(mat7x7)

    # 저장(기존 스키마)
    existing = (
        db.query(UserTypeHistory)
        .filter(UserTypeHistory.user_id == user_id,
                UserTypeHistory.week_start_date == week_start)
        .first()
    )
    if existing:
        existing.sincerity = p["성실도"]
        existing.repetition = p["반복형"]
        existing.timeslot  = p["시간대"]
        db.commit(); db.refresh(existing)
    else:
        rec = UserTypeHistory(
            user_id=user_id, week_start_date=week_start,
            sincerity=p["성실도"], repetition=p["반복형"], timeslot=p["시간대"]
        )
        db.add(rec); db.commit(); db.refresh(rec)

    return {
        "message": "자동 예측 및 저장 완료",
        "prediction": p,
        "week_start_date": week_start.isoformat(),
        "missing_days": missing_days,
        "raw_pattern": summary.get("raw_pattern"),
        "repetition_count": summary.get("repetition_count"),
        "weekend_share": summary.get("weekend_share"),
        "peak_day": summary.get("peak_day"),
        "burstiness": summary.get("burstiness"),
        "filled_input_preview": mat7x7,
    }


# ─────────────────────────────────────────────────────────────
# 데이터 부족 시 timeslot 폴백 (최근 7일 최댓값)
# ─────────────────────────────────────────────────────────────
def auto_predict_and_save_user_type_with_fallback(
    user_id: int,
    db: Session,
    minutes_threshold: int = 60,
    active_days_threshold: int = 2,
):
    result = auto_predict_and_save_user_type(user_id, db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)

    week_rows = (
        db.query(UserStudyDaily)
        .filter(
            UserStudyDaily.user_id == user_id,
            UserStudyDaily.study_date >= week_start,
            UserStudyDaily.study_date <= week_end,
        )
        .all()
    )
    total_minutes_week = sum(r.total_minutes or 0 for r in week_rows)
    active_days = sum(1 for r in week_rows if (r.total_minutes or 0) > 0)

    if total_minutes_week <= minutes_threshold or active_days <= active_days_threshold:
        last7_start = today - timedelta(days=6)
        last7_rows = (
            db.query(UserStudyDaily)
            .filter(
                UserStudyDaily.user_id == user_id,
                UserStudyDaily.study_date >= last7_start,
                UserStudyDaily.study_date <= today,
            )
            .all()
        )
        totals = {
            "오전": sum(r.morning_minutes or 0 for r in last7_rows),
            "오후": sum(r.afternoon_minutes or 0 for r in last7_rows),
            "저녁": sum(r.evening_minutes or 0 for r in last7_rows),
            "심야": sum(r.night_minutes or 0 for r in last7_rows),
        }
        fallback_timeslot = max(totals, key=totals.get) if any(totals.values()) else "오전"

        uth = (
            db.query(UserTypeHistory)
            .filter(
                UserTypeHistory.user_id == user_id,
                UserTypeHistory.week_start_date == week_start,
            )
            .first()
        )
        if uth:
            uth.timeslot = fallback_timeslot
            db.commit()
            db.refresh(uth)

        if isinstance(result, dict):
            pred = result.get("prediction", {})
            pred["시간대"] = fallback_timeslot
            result["prediction"] = pred
            result["fallback_used"] = True
            result["fallback_reason"] = {
                "total_minutes_week": total_minutes_week,
                "active_days": active_days,
                "minutes_threshold": minutes_threshold,
                "active_days_threshold": active_days_threshold,
                "basis": "최근 7일 합계 최빈 시간대",
            }
    else:
        if isinstance(result, dict):
            result["fallback_used"] = False

    return result



