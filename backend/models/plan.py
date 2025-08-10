# models/plan.py
from sqlalchemy.orm import relationship 
from sqlalchemy import Column, Integer, String, Date, Boolean, ForeignKey
from db import Base

class Plan(Base):
    __tablename__ = "plan"

    plan_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))
    subject_id = Column(Integer, ForeignKey("subject.subject_id", ondelete="CASCADE"))
    plan_name = Column(String(255))
    plan_date = Column(Date, nullable=True)
    complete = Column(Boolean, default=False)
    plan_time = Column(Integer, nullable=True)  # 이름 변경 (estimated_time_min → plan_time)
 # 관계
    user = relationship("User", back_populates="plans")
    subject = relationship("Subject", back_populates="plans")
    row_plan = relationship("RowPlan", back_populates="plans")  # 양방향 연결


