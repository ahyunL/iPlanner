# backend/routers/row_plan.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from db import get_db
from models.row_plan import RowPlan
from schemas.row_plan_schema import RowPlanCreate, RowPlanOut
from fastapi import Request
from utils.auth import get_user_id_from_token 

router = APIRouter()


@router.post("/")
def create_row_plan(request: Request, row_plan: RowPlanCreate, db: Session = Depends(get_db)):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        print("인증 토큰 없음")
        raise HTTPException(status_code=401, detail="토큰이 없습니다.")

    token = auth_header.split(" ")[1]
    user_id = get_user_id_from_token(token)
    print(f"Access Token 인증 성공: user_id - {user_id}")

    # 받은 row_plan 데이터 출력
    print("받은 row_plan 데이터:", row_plan.dict())

    try:
        new_plan = RowPlan(
            user_id=user_id,
            subject_id=row_plan.subject_id,
            row_plan_name=row_plan.row_plan_name,
            type=row_plan.type,
            repetition=row_plan.repetition,
            ranking=row_plan.ranking,
            plan_time=row_plan.plan_time

        )
        print("row_plan 저장 직전:", {
            "user_id": user_id,
            "subject_id": row_plan.subject_id,
            "ranking": row_plan.ranking,
            "row_plan_name": row_plan.row_plan_name
        })

        db.add(new_plan)
        db.commit()
        db.refresh(new_plan)
        print("row_plan 저장 성공:", new_plan.row_plan_id)
        return {"row_plan_id": new_plan.row_plan_id}

    except Exception as e:
        db.rollback()
        print("row_plan 저장 중 예외 발생:", str(e))
        raise HTTPException(status_code=500, detail="row_plan 저장 실패")


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
