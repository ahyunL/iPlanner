from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from db import get_db
from models import plan as plan_model, subject as subject_model, timer as timer_model, user as user_model, \
    row_plan as row_plan_model
from pydantic import BaseModel
import datetime
from utils.auth import get_current_user
from services.ai_planner import generate_and_save_plans
# plan.py 상단에 추가
from services.schedule_plans import run_schedule_for_user

router = APIRouter()


# ---------------------- 기본 CRUD ---------------------- #

class PlanCreate(BaseModel):
    subject_id: int
    plan_name: str
    plan_date: datetime.date
    complete: bool


@router.post("/plans")
def create_plan(
        plan: PlanCreate,
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    new_plan = plan_model.Plan(**plan.dict(), user_id=current_user.user_id)
    db.add(new_plan)
    db.commit()
    db.refresh(new_plan)
    return {"message": "Plan added", "planId": new_plan.plan_id}


@router.get("/plans")
def get_user_plans(
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    return db.query(plan_model.Plan).filter(plan_model.Plan.user_id == current_user.user_id).all()


@router.get("/plans/subject/{subject_id}")
def get_subject_plans(
        subject_id: int,
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    return db.query(plan_model.Plan).filter(
        plan_model.Plan.user_id == current_user.user_id,
        plan_model.Plan.subject_id == subject_id
    ).all()


# ---------------------- 프론트 연동 API ---------------------- #

@router.get("/today")
def get_today_plans(
        date_param: datetime.date = Query(..., alias="date"),
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    print("[TODAY] 요청 날짜:", date_param)
    return db.query(plan_model.Plan).filter(
        plan_model.Plan.user_id == current_user.user_id,
        func.date(plan_model.Plan.plan_date) == date_param
    ).all()


@router.get("/weekly")
def get_weekly_plans(
        start_date: datetime.date = Query(..., alias="start"),
        end_date: datetime.date = Query(..., alias="end"),
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    results = (
        db.query(plan_model.Plan, subject_model.Subject.test_name.label("subject"))
        .outerjoin(subject_model.Subject, plan_model.Plan.subject_id == subject_model.Subject.subject_id)
        .filter(plan_model.Plan.user_id == current_user.user_id)
        .filter(func.date(plan_model.Plan.plan_date) >= start_date)
        .filter(func.date(plan_model.Plan.plan_date) <= end_date)
        .all()
    )

    print("/weekly 조회 결과:")
    for plan, subject in results:
        print("   -", plan.plan_id, plan.plan_name, plan.plan_date, subject, plan.plan_time)

    return [
        {
            "plan_id": plan.plan_id,
            "plan_name": plan.plan_name,
            "plan_date": plan.plan_date.isoformat() if plan.plan_date else "",
            "complete": bool(plan.complete),
            "subject": subject or "미지정",
            "plan_time": plan.plan_time,
        }
        for plan, subject in results
    ]


@router.get("/by-date")
def get_calendar_events(
        date_param: datetime.date = Query(..., alias="date"),
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    print("[BY DATE] 요청 날짜:", date_param)
    return db.query(plan_model.Plan).filter(
        plan_model.Plan.user_id == current_user.user_id,
        func.date(plan_model.Plan.plan_date) == date_param
    ).all()



class CompleteUpdate(BaseModel):
    complete: bool

@router.patch("/{plan_id}/complete")
def update_complete(
        plan_id: int,
        update: CompleteUpdate,  # ✅ 요청에서 complete 값 받기
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    plan = db.query(plan_model.Plan).filter(
        plan_model.Plan.plan_id == plan_id,
        plan_model.Plan.user_id == current_user.user_id
    ).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    plan.complete = update.complete  # ✅ True or False 저장
    db.commit()
    return {"message": f"Marked {'complete' if update.complete else 'incomplete'}"}


@router.get("/stat")
def get_plan_stats(
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    today = datetime.date.today()
    weekday = today.weekday()
    start_week = today - datetime.timedelta(days=weekday)
    end_week = start_week + datetime.timedelta(days=6)

    weekday_map = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
    today_goal = getattr(current_user, f"study_time_{weekday_map[weekday]}", 0)
    weekly_goal = sum([getattr(current_user, f"study_time_{d}", 0) for d in weekday_map])

    today_timer = db.query(timer_model.Timer).filter(
        timer_model.Timer.user_id == current_user.user_id,
        timer_model.Timer.study_date == today
    ).first()
    today_minutes = today_timer.total_minutes if today_timer else 0

    weekly_minutes = sum([
        t.total_minutes for t in db.query(timer_model.Timer)
        .filter(timer_model.Timer.user_id == current_user.user_id)
        .filter(timer_model.Timer.study_date >= start_week)
        .filter(timer_model.Timer.study_date <= end_week)
        .all()
    ])

    return {
        "today_rate": min(today_minutes / today_goal, 1.0) if today_goal > 0 else 0.0,
        "today_minutes": today_minutes,
        "weekly_rate": min(weekly_minutes / weekly_goal, 1.0) if weekly_goal > 0 else 0.0,
        "weekly_minutes": weekly_minutes,
    }



@router.post("/schedule")
def schedule_ai_plan(
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    # ✅ GPT 기반 계획 자동 배정 로직 실행
    result = run_schedule_for_user(current_user.user_id, db)

    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    elif "warning" in result:
        return {"message": result["warning"]}

    return {"message": result["message"]}


@router.get("/weekly-grouped")
def get_weekly_grouped_plans(
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    results = (
        db.query(plan_model.Plan, subject_model.Subject.test_name.label("subject"))
        .join(subject_model.Subject, plan_model.Plan.subject_id == subject_model.Subject.subject_id)
        .filter(plan_model.Plan.user_id == current_user.user_id)
        .all()
    )

    grouped = {}
    for plan, subject in results:
        key = f"{subject or '미지정'}_{plan.subject_id}"
        if key not in grouped:
            grouped[key] = []
        grouped[key].append({
            "plan_id": plan.plan_id,
            "plan_name": plan.plan_name,
            "complete": bool(plan.complete),
            "plan_date": plan.plan_date.isoformat() if plan.plan_date else None
        })
    return grouped

#if /by-date 다른 곳에 안쓰이면, 그것을 대체해도 됨.
@router.get("/by-date-with-subject")
def get_calendar_events_with_subject(
        date_param: datetime.date = Query(..., alias="date"),
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    print("[BY DATE + SUBJECT] 요청 날짜:", date_param)

    results = (
        db.query(plan_model.Plan, subject_model.Subject.test_name.label("subject"))
        .outerjoin(subject_model.Subject, plan_model.Plan.subject_id == subject_model.Subject.subject_id)
        .filter(plan_model.Plan.user_id == current_user.user_id)
        .filter(func.date(plan_model.Plan.plan_date) == date_param)
        .all()
    )

    return [
        {
            "plan_id": plan.plan_id,
            "plan_name": plan.plan_name,
            "plan_date": plan.plan_date.isoformat() if plan.plan_date else None,
            "complete": bool(plan.complete),
            "subject": subject or "미지정"
        }
        for plan, subject in results
    ]


#민경언니
'''# backend/routers/plan.py (계획 등록 + 조회)
# /plans 등록 및 조회 API (user_id, subject_id)
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from db import get_db
from models import plan as plan_model
from pydantic import BaseModel
from typing import List
from typing import Optional  

router = APIRouter()

class PlanCreate(BaseModel):
    user_id: int
    subject_id: int
    plan_name: str
    plan_date: str
    complete: bool
    plan_time: int  # ✅ 추가됨
    row_plan_id: Optional[int] = None  # ✅ 선택 필드 추가

@router.post("/plans")
def create_plan(plan: PlanCreate, db: Session = Depends(get_db)):
    new_plan = plan_model.Plan(**plan.dict())
    db.add(new_plan)
    db.commit()
    db.refresh(new_plan)
    return {"message": "Plan added", "planId": new_plan.plan_id}

@router.get("/plans/{user_id}")
def get_user_plans(user_id: int, db: Session = Depends(get_db)):
    plans = db.query(plan_model.Plan).filter(plan_model.Plan.user_id == user_id).all()
    return plans

@router.get("/plans/subject/{subject_id}")
def get_subject_plans(subject_id: int, db: Session = Depends(get_db)):
    plans = db.query(plan_model.Plan).filter(plan_model.Plan.subject_id == subject_id).all()
    return plans
'''