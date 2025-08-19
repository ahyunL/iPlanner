# 파일 경로: schemas/row_plan_schema.py

from pydantic import BaseModel
from typing import Optional
from datetime import date

# RowPlan 생성 시 사용하는 스키마
# schemas/row_plan_schema.py

from pydantic import BaseModel

class RowPlanCreate(BaseModel):
    subject_id: int
    row_plan_name: str
    type: str
    repetition: int
    ranking: int
    plan_time: int
    class Config:
        from_attributes = True  


# 클라이언트에게 반환할 RowPlan 정보 스키마
class RowPlanOut(BaseModel):
    row_plan_id: int
    subject_id: int
    user_id: int
    ranking: int
    row_plan_name: str
    type: str
    repetition: int
    plan_time: int
    class Config:
        from_attributes = True  

