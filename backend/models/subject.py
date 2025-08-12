# backend/models/subjects.py
# 과목 테이블 모델
from sqlalchemy import Column, Integer, String, Date, ForeignKey
from db import Base
from sqlalchemy.orm import relationship

class Subject(Base):
    __tablename__ = "subject"

    subject_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))

    field = Column(String(30))
    test_name = Column(String(50))
    test_date = Column(Date)
    start_date = Column(Date)
    end_date = Column(Date)

    row_plans = relationship("RowPlan", back_populates="subject", cascade="all, delete-orphan")

    user = relationship("User", back_populates="subjects")
    plans = relationship("Plan", back_populates="subject")
#민경언니 파일
#관계설정, nullable 여부 등 다름 but 아직 크게 차이없을 것 같아서 추후 오류 발생시 통합
'''class Subject(Base):
    __tablename__ = "subject"

    subject_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"), nullable=False)

    field = Column(String(30), nullable=False)        # 전공/계열 (ex. 영어, 수학 등)
    test_name = Column(String(50), nullable=False)    # 시험명 (ex. 수능, 토익 등)
    test_date = Column(Date, nullable=False)          # 시험일
    start_date = Column(Date, nullable=False)         # 학습 시작일
    end_date = Column(Date, nullable=False)           # 학습 종료일

    # 관계 설정
    user = relationship("User", back_populates="subjects")
    row_plans = relationship("RowPlan", back_populates="subject", cascade="all, delete-orphan")
    plans = relationship("Plan", back_populates="subject", cascade="all, delete-orphan")
'''