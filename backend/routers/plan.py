# backend/routers/plan.py (계획 등록 + 조회)
# /plans 등록 및 조회 API (user_id, subject_id)
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from db import get_db
from models import plan as plan_model
from pydantic import BaseModel
from typing import List

router = APIRouter()

class PlanCreate(BaseModel):
    user_id: int
    subject_id: int
    plan_name: str
    plan_date: str
    complete: bool

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
