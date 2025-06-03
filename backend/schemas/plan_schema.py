# backend/schemas/plan_schema.py
# 사용자가 보낸 학습 자료 입력 항목

from pydantic import BaseModel
from typing import List, Optional
from datetime import date
from schemas.row_plan_schema import RowPlanOut
# ✅ row_plan 관련 스키마 (그대로 유지)
class RowPlanCreate(BaseModel):
    subject_id: int
    row_plan_name: str
    type: str
    repetition: int
    ranking: int

# ✅ 요청용: 학습계획 생성 시 사용
class ToDoRequest(BaseModel):
    user_id: int
    subject_id: int
    row_plans: List[RowPlanOut]

# ✅ 응답용: 계획 항목 반환
class ToDoItem(BaseModel):
    plan_id: int
    plan_name: str
    plan_time: int                    # ✅ estimated_time_min → plan_time
    plan_date: Optional[date] = None
    complete: Optional[bool] = False # ✅ boolean 값도 명확히 추가

    class Config:
        from_attributes = True  # ✅ v2 표준 (orm_mode 대체)
#민경언니
'''# backend/schemas/plan_schema.py
# 사용자가 보낸 학습 자료 입력 항목

# backend/schemas/plan_schema.py

from pydantic import BaseModel
from typing import List, Optional
from datetime import date

# ✅ RowPlan 입력용 (혼동 방지 위해 이름 변경)
class RowPlanInput(BaseModel):
    row_plan_name: str
    type: str
    repetition: int
    ranking: int

# ✅ 계획 생성 요청용
class ToDoRequest(BaseModel):
    user_id: int
    subject_id: int
    row_plans: List[RowPlanInput]

# ✅ 계획 응답용
class ToDoItem(BaseModel):
    plan_id: int
    plan_name: str
    plan_time: int
    plan_date: Optional[date] = None
    complete: Optional[bool] = False
    user_id: Optional[int] = None
    subject_id: Optional[int] = None
    row_plan_id: Optional[int] = None

    class Config:
        from_attributes = True

'''