# backend/models/row_plan.py
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from db import Base
from sqlalchemy import Column, Integer, ForeignKey
from sqlalchemy.orm import relationship
from .user import User  # 혹은 상대 경로에 맞게 수정

class RowPlan(Base):

    __tablename__ = "row_plan"

    row_plan_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id"))  # ✅ 이 줄이 있어야 함

    # 자료 이름 (예: 리딩파워, 수능특강 영어)
    row_plan_name = Column(String(50), nullable=False)  # ✅ 수정: 길이 지정

    user = relationship("User", back_populates="row_plan")  #
    # 자료 유형 (예: 책, 인강, PDF, 앱, 유튜브 등)
    type = Column(String(30), nullable=False)           # ✅ 수정: 길이 지정

    # 반복 횟수 (예: 1회 반복, 2회 반복)
    repetition = Column(Integer, nullable=False, default=1)

    # 우선순위 (낮을수록 더 먼저 계획됨)
    ranking = Column(Integer, nullable=False, default=1)
    # 예상 학습 시간 (분 단위)
    plan_time = Column(Integer, nullable=False, default=0)  # ✅ 추가

    # 외래키: 어떤 과목에 속한 자료인지
    subject_id = Column(Integer, ForeignKey("subject.subject_id"), nullable=False)  # 테이블명 수정

    # 관계 설정 (옵션): Subject와 연결

    plan_id = Column(Integer, ForeignKey("plan.plan_id"), nullable=True)
    user = relationship("User", back_populates="row_plans")  # ✅ 수정됨
    subject = relationship("Subject", back_populates="row_plans")  # ✅ 수정됨
    plans = relationship("Plan", back_populates="row_plan")

