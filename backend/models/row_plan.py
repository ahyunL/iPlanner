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

    # 외래키: 어떤 과목에 속한 자료인지
    subject_id = Column(Integer, ForeignKey("subject.subject_id"), nullable=False)  # 테이블명 수정

    # 관계 설정 (옵션): Subject와 연결
    plans = relationship("Plan", back_populates="row_plan")
    subject = relationship("Subject", back_populates="row_plan")
    plan_id = Column(Integer, ForeignKey("plan.plan_id"))
# 민경언니 파일 - 관계설정 약간 다름 혹시 몰라 추후 프론트까지 완료 후 오류 발생 시 관계 추가하기
#관계가 일대일인지, 일대다 인지 내꺼랑 차이가 있어서 함부로 업데이트 안함(아마 row_plan모델에 subject_id 있는지 여부때문일 듯)
'''class RowPlan(Base):
    __tablename__ = "row_plan"

    row_plan_id = Column(Integer, primary_key=True, index=True)

    subject_id = Column(Integer, ForeignKey("subject.subject_id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"), nullable=False)

    ranking = Column(Integer, nullable=False)
    row_plan_name = Column(String(50), nullable=False)
    type = Column(String(30), nullable=False)
    repetition = Column(Integer, nullable=False)

    # 관계
    subject = relationship("Subject", back_populates="row_plans")
    user = relationship("User", back_populates="row_plans")
    plans = relationship("Plan", back_populates="row_plan", cascade="all, delete-orphan")
'''