# backend/schemas/plan_schema.py
# 사용자가 보낸 학습 자료 입력 항목

from pydantic import BaseModel
from typing import List, Optional
from datetime import date
from schemas.row_plan_schema import RowPlanOut
# row_plan 관련 스키마 (그대로 유지)
class RowPlanCreate(BaseModel):
    subject_id: int
    row_plan_name: str
    type: str
    repetition: int
    ranking: int

# 요청용: 학습계획 생성 시 사용
class ToDoRequest(BaseModel):
    user_id: int
    subject_id: int
    row_plans: List[RowPlanOut]

# 응답용: 계획 항목 반환
class ToDoItem(BaseModel):
    plan_id: int
    plan_name: str
    plan_time: int                   
    plan_date: Optional[date] = None
    complete: Optional[bool] = False 

    class Config:
        from_attributes = True  
