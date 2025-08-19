
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy import func

from services.schedule_plans import run_schedule_for_user
from db import get_db
from models import plan as plan_model, subject as subject_model, timer as timer_model, user as user_model
from pydantic import BaseModel
from utils.auth import get_current_user
from models import Plan
from utils.auth import get_user_id_from_token

from typing import Optional
import datetime
import traceback
from services.schedule_plans import run_schedule_for_user as assign_plan_dates 
from services.ai_planner import generate_and_save_plans  

router = APIRouter()
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from db import get_db
import os

from models.row_plan import RowPlan  # 8월 13일 민경 추가

# .env에서 불러오는 시크릿 키와 알고리즘
SECRET_KEY = os.getenv("SECRET_KEY", "default_secret")  # .env에 SECRET_KEY 값이 있어야 함
ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user_id(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> int:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Token payload에 user_id가 없습니다.")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")


# ---------------------- 모델 ---------------------- #

class PlanCreate(BaseModel):
    subject_id: int
    plan_name: str
    plan_date: datetime.date
    complete: bool
    plan_time: int
    row_plan_id: Optional[int] = None


class CompleteUpdate(BaseModel):
    complete: bool


# ---------------------- CRUD ---------------------- #

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


class CompleteUpdate(BaseModel):
    complete: bool


@router.patch("/{plan_id}/complete")
def update_complete(
        plan_id: int,
        update: CompleteUpdate,  # 요청에서 complete 값 받기
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    plan = db.query(plan_model.Plan).filter(
        plan_model.Plan.plan_id == plan_id,
        plan_model.Plan.user_id == current_user.user_id
    ).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    plan.complete = update.complete  # True or False 저장
    db.commit()
    return {"message": f"Marked {'complete' if update.complete else 'incomplete'}"}


# ---------------------- 일정 조회 ---------------------- #

@router.get("/today")
def get_today_plans(
        date_param: datetime.date = Query(..., alias="date"),
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    print("[TODAY] 요청 날짜:", date_param)

    results = (
        db.query(plan_model.Plan, subject_model.Subject.test_name.label("subject_name"))
        .outerjoin(subject_model.Subject, plan_model.Plan.subject_id == subject_model.Subject.subject_id)
        .filter(plan_model.Plan.user_id == current_user.user_id)
        .filter(func.date(plan_model.Plan.plan_date) == date_param)
        .all()
    )

    # 여기 로그 추가
    for plan, subject_name in results:
        print(f"PLAN: {plan.plan_name}, subject_id={plan.subject_id}, subject_name={subject_name}")

    return [
        {
            "plan_id": plan.plan_id,
            "plan_name": plan.plan_name,
            "plan_time": plan.plan_time,
            "plan_date": plan.plan_date.isoformat() if plan.plan_date else None,
            "complete": bool(plan.complete),
            "subject_name": subject_name or "미지정"
        }
        for plan, subject_name in results
    ]


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


@router.get("/monthly")
def get_monthly_plans(
    year: int = Query(...),
    month: int = Query(...),
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    first_day = datetime.date(year, month, 1)
    # 다음 달 1일에서 하루 빼기 = 해당 월의 마지막 날
    next_month = first_day.replace(day=28) + datetime.timedelta(days=4)
    last_day = next_month - datetime.timedelta(days=next_month.day)

    results = (
        db.query(plan_model.Plan, subject_model.Subject.test_name.label("subject"))
        .outerjoin(subject_model.Subject, plan_model.Plan.subject_id == subject_model.Subject.subject_id)
        .filter(plan_model.Plan.user_id == current_user.user_id)
        .filter(plan_model.Plan.plan_date >= first_day)
        .filter(plan_model.Plan.plan_date <= last_day)
        .all()
    )

    return [
        {
            "plan_id": plan.plan_id,
            "plan_name": plan.plan_name,
            "plan_date": plan.plan_date.isoformat(),
            "subject": subject or "미지정",
            "complete": bool(plan.complete)
        }
        for plan, subject in results
    ]


@router.get("/by-date")
def get_calendar_events(
        date_param: datetime.date = Query(..., alias="date"),
        db: Session = Depends(get_db),
        current_user: user_model.User = Depends(get_current_user)
):
    return db.query(plan_model.Plan).filter(
        plan_model.Plan.user_id == current_user.user_id,
        func.date(plan_model.Plan.plan_date) == date_param
    ).all()




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
            "plan_time": plan.plan_time,
            "complete": bool(plan.complete),
            "plan_date": plan.plan_date.isoformat() if plan.plan_date else None,
            "subject_id": plan.subject_id,
        })
    return grouped


# ---------------------- AI 계획 생성 ---------------------- #


from services.ai_planner import generate_and_save_plans
from services.schedule_plans import run_schedule_for_user as assign_plan_dates
@router.post("/schedule")
def schedule_ai_plan(
    subject_id: int = Query(...),
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user)
):
    try:
        # 선택된 subject_id에 해당하는 과목만 조회
        subject = db.query(subject_model.Subject).filter(
            subject_model.Subject.user_id == current_user.user_id,
            subject_model.Subject.subject_id == subject_id
        ).first()

        if not subject:
            raise HTTPException(status_code=404, detail="해당 과목이 존재하지 않습니다.")

        # 1. 계획 생성
        print(f"✅ AI 계획 생성 시작: user_id={current_user.user_id}, subject_id={subject_id}")
        generate_and_save_plans(current_user.user_id, subject.subject_id)

        db.commit()

        # 2. GPT 기반 날짜 자동 배정
        result = assign_plan_dates(current_user.user_id, db)

        if "error" in result:
            raise HTTPException(status_code=400, detail=result["error"])
        elif "warning" in result:
            return {"message": result["warning"]}

        return {"message": result["message"]}

    except Exception as e:
        print("AI 계획 생성 중 오류:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="AI 계획 생성 중 서버 오류 발생")
@router.post("/calendar")
def assign_calendar_dates(
    current_user: user_model.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user_id = current_user.user_id
    print("✅ POST /plan/calendar 진입 성공 - user_id:", user_id)

    plans = db.query(Plan).filter(Plan.user_id == user_id).all()
    if not plans:
        raise HTTPException(status_code=400, detail="계획이 존재하지 않습니다. 먼저 계획을 생성하세요.")

    try:
        result = run_schedule_for_user(user_id=user_id, db=db)
        return {"message": "날짜 배정 완료", "result": result}
    except Exception as e:
        print("❌ 날짜 배정 중 오류:", e)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"날짜 배정 중 오류 발생: {str(e)}")

# ---------------------- 메인페이지 도넛 그래프 공부 달성도 ---------------------- #

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

# ---------------------- 플랜 삭제 ---------------------- #

@router.delete("/{plan_id}")
def delete_plan(plan_id: int, request: Request, db: Session = Depends(get_db)):
    try:
        token = request.headers.get("Authorization").split(" ")[1]
        user_id = get_user_id_from_token(token)

        print(f"🧾 user_id from token: {user_id}")
        print(f"🧾 plan_id: {plan_id}")

        plan = db.query(Plan).filter(
            Plan.plan_id == plan_id,
            Plan.user_id == user_id
        ).first()

        print(f"🧾 plan found? {plan is not None}")

        if not plan:
            raise HTTPException(status_code=404, detail="해당 계획이 존재하지 않거나 권한이 없습니다.")

        db.delete(plan)
        db.commit()
        print("✅ commit 완료")

        return {"message": f"Plan {plan_id} deleted"}

    except Exception as e:
        db.rollback()
        print("❌ 삭제 중 오류 발생:", e)
        raise HTTPException(status_code=500, detail="삭제 중 서버 오류 발생")


#8월 13일 민경 교체
@router.delete("/by-subject/{subject_id}")
def delete_plans_by_subject(
    subject_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    token = request.headers.get("Authorization").split(" ")[1]
    user_id = get_user_id_from_token(token)

    # ORM per-row 삭제: cascade/순서가 제대로 적용되어 complete=1 섞여 있어도 안전
    plans = db.query(Plan).filter(
        Plan.subject_id == subject_id,
        Plan.user_id == user_id
    ).all()

    count = 0
    for p in plans:
        db.delete(p)
        count += 1

    db.commit()
    return {"message": f"{count}개의 plan이 삭제되었습니다."}


@router.delete("/by-subject/{subject_id}/all")
def delete_everything_of_subject(
    subject_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    token = request.headers.get("Authorization").split(" ")[1]
    user_id = get_user_id_from_token(token)

    # 1) Plan 전부 per-row 삭제 (ORM cascade/순서 보장)
    plans = db.query(Plan).filter(
        Plan.subject_id == subject_id,
        Plan.user_id == user_id
    ).all()

    plan_count = 0
    for p in plans:
        db.delete(p)
        plan_count += 1

    db.flush()  # FK 참조 깨끗이 정리된 상태로 진행

    # 2) RowPlan은 이제 참조 없으므로 bulk 삭제 OK
    rowplan_deleted = db.query(RowPlan).filter(
        RowPlan.subject_id == subject_id,
        RowPlan.user_id == user_id
    ).delete(synchronize_session=False)

    db.commit()
    return {
        "message": f"삭제 완료: plan {plan_count}개, row_plan {rowplan_deleted}개"
    }
