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
    # RowPlan과의 관계 추가
    row_plans = relationship("RowPlan", back_populates="subject")  # back_populates 추가