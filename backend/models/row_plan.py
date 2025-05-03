# backend/models/row_plan.py
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from db import Base

class RowPlan(Base):
    """
    학습 자료(교재, 인강 등)를 저장하는 테이블입니다.
    각 과목(subject)에 연결되며, 사용자 입력 기반으로 생성됩니다.
    """
    __tablename__ = "row_plans"

    id = Column(Integer, primary_key=True, index=True)

    # 자료 이름 (예: 리딩파워, 수능특강 영어)
    row_plan_name = Column(String(50), nullable=False)  # ✅ 수정: 길이 지정

    # 자료 유형 (예: 책, 인강, PDF, 앱, 유튜브 등)
    type = Column(String(30), nullable=False)           # ✅ 수정: 길이 지정

    # 단위 이름 (예: 챕터, 강의, 주차 등)
    unit_name = Column(String(30), nullable=False)      # ✅ 수정: 길이 지정
    # 단위 개수 (예: 15, 20 등)
    unit_count = Column(Integer, nullable=False)

    # 반복 횟수 (예: 1회 반복, 2회 반복)
    repetition = Column(Integer, nullable=False, default=1)

    # 우선순위 (낮을수록 더 먼저 계획됨)
    ranking = Column(Integer, nullable=False, default=1)

    # 외래키: 어떤 과목에 속한 자료인지
    subject_id = Column(Integer, ForeignKey("subject.subject_id"), nullable=False)  # 테이블명 수정

    # 관계 설정 (옵션): Subject와 연결
    subject = relationship("Subject", back_populates="row_plans")
