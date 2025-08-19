
from datetime import time, timedelta
from sqlalchemy.orm import Session
from models.timer import Timer
from models.plan import Plan
from models.user_study_daily import UserStudyDaily
from models.row_plan import RowPlan



def get_time_slot_minutes(start_dt, end_dt):
    slots = {"morning": 0, "afternoon": 0, "evening": 0, "night": 0}
    
    # 정확한 분 단위로 루프
    total_minutes = int((end_dt - start_dt).total_seconds() // 60)

    for i in range(total_minutes):
        current = start_dt + timedelta(minutes=i)
        t = current.time()
        if time(5, 0) <= t < time(12, 0):
            slots["morning"] += 1
        elif time(12, 0) <= t < time(17, 0):
            slots["afternoon"] += 1
        elif time(17, 0) <= t < time(22, 0):
            slots["evening"] += 1
        else:
            slots["night"] += 1
    return slots





def aggregate_user_study_data(user_id: int, target_date, db: Session) -> dict:
    from models.timer import Timer
    from models.plan import Plan
    from models.row_plan import RowPlan

    def get_time_slot_minutes(start_dt, end_dt):
        from datetime import time, timedelta
        slots = {"morning": 0, "afternoon": 0, "evening": 0, "night": 0}
        total_minutes = int((end_dt - start_dt).total_seconds() // 60)

        for i in range(total_minutes):
            current = start_dt + timedelta(minutes=i)
            t = current.time()
            if time(5, 0) <= t < time(12, 0):
                slots["morning"] += 1
            elif time(12, 0) <= t < time(17, 0):
                slots["afternoon"] += 1
            elif time(17, 0) <= t < time(22, 0):
                slots["evening"] += 1
            else:
                slots["night"] += 1
        return slots

    # 1. 타이머 조회 및 시간대별 분할
    timers = db.query(Timer).filter(
        Timer.user_id == user_id,
        Timer.study_date == target_date
    ).all()

    total_minutes = 0
    slot_minutes = {"morning": 0, "afternoon": 0, "evening": 0, "night": 0}

    for t in timers:
        total_minutes += t.total_minutes
        if t.start_time and t.end_time:
            split = get_time_slot_minutes(t.start_time, t.end_time)
            for k in slot_minutes:
                slot_minutes[k] += split[k]

    # 2. 오늘의 plan 목록 조회
    plans = db.query(Plan).filter(
        Plan.user_id == user_id,
        Plan.plan_date == target_date
    ).all()

    plan_name_set = set()
    repetition_values = []

    for plan in plans:
        full_name = plan.plan_name
        if full_name:
            base_name = full_name.split('-')[0].strip()  # ex) 영어 인강 - 1회차 챕터 1 → 영어 인강

            if base_name in plan_name_set:
                continue
            plan_name_set.add(base_name)

            row_plan = db.query(RowPlan).filter(
                RowPlan.user_id == user_id,
                RowPlan.subject_id == plan.subject_id,
                RowPlan.row_plan_name == base_name
            ).first()

            if row_plan:
                repetition_values.append(row_plan.repetition)

    repetition = round(sum(repetition_values) / len(repetition_values), 2) if repetition_values else 0

    # 3. 결과 리턴
    return {
        "study_date": target_date,
        "total_minutes": total_minutes,
        "morning_minutes": slot_minutes["morning"],
        "afternoon_minutes": slot_minutes["afternoon"],
        "evening_minutes": slot_minutes["evening"],
        "night_minutes": slot_minutes["night"],
        "repetition": repetition,
    }



def upsert_user_study_daily(user_id: int, target_date, db: Session):
    data = aggregate_user_study_data(user_id, target_date, db)

    record = db.query(UserStudyDaily).filter(
        UserStudyDaily.user_id == user_id,
        UserStudyDaily.study_date == target_date
    ).first()

    if record:
        record.total_minutes = data["total_minutes"]
        record.morning_minutes = data["morning_minutes"]
        record.afternoon_minutes = data["afternoon_minutes"]
        record.evening_minutes = data["evening_minutes"]
        record.night_minutes = data["night_minutes"]
        record.repetition = data["repetition"]
    else:
        record = UserStudyDaily(**data, user_id=user_id)
        db.add(record)

    db.commit()
    db.refresh(record)
    return record


