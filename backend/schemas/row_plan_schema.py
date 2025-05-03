# 파일 경로: schemas/row_plan_schema.py

from pydantic import BaseModel
from typing import Optional
from datetime import date

# RowPlan 생성 시 사용하는 스키마
class RowPlanCreate(BaseModel):
    plan_id: int               # 연관된 Plan의 ID
    subject_id: int            # 연관된 과목의 ID
    row_title: str             # 학습 항목의 제목 (예: 챕터 1, 강의 2 등)
    row_order: int             # 학습 항목의 순서
    plan_time: int             # 해당 항목에 할당된 학습 시간 (분 단위)
    relevance: float           # 중요도 혹은 연관도 (0.0 ~ 1.0)
    start_date: date           # 해당 항목의 시작 날짜
    end_date: date             # 해당 항목의 종료 날짜

    class Config:
        from_attributes = True  # ✅ v2 표준


# 클라이언트에게 반환할 RowPlan 정보 스키마
class RowPlanOut(BaseModel):
    id: int                    # RowPlan의 고유 ID
    plan_id: int
    subject_id: int
    row_title: str
    row_order: int
    plan_time: int
    relevance: float
    start_date: date
    end_date: date

    class Config:
        from_attributes = True  # ✅ v2 표준

