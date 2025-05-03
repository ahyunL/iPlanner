# backend/routers/row_plan.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from db import get_db
from models.row_plan import RowPlan
from schemas.row_plan_schema import RowPlanCreate, RowPlanOut

router = APIRouter()

@router.post("/row-plans", response_model=RowPlanOut)
def create_row_plan(plan: RowPlanCreate, db: Session = Depends(get_db)):
    """
    새로운 학습 자료(row_plan)를 생성하는 API입니다.
    클라이언트로부터 JSON 요청을 받아 DB에 저장합니다.
    """
    db_plan = RowPlan(**plan.dict())
    db.add(db_plan)
    db.commit()
    db.refresh(db_plan)
    return db_plan


@router.get("/row-plans", response_model=List[RowPlanOut])
def get_all_row_plans(db: Session = Depends(get_db)):
    """
    전체 학습 자료 리스트를 조회하는 API입니다.
    """
    return db.query(RowPlan).all()


@router.get("/row-plans/subject/{subject_id}", response_model=List[RowPlanOut])
def get_row_plans_by_subject(subject_id: int, db: Session = Depends(get_db)):
    """
    특정 과목(subject_id)에 속한 학습 자료만 조회합니다.
    """
    return db.query(RowPlan).filter(RowPlan.subject_id == subject_id).all()
