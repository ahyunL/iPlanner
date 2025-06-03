# models/plan.py
from sqlalchemy.orm import relationship  # ✅ 필요!
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
    plan_time = Column(Integer, nullable=True)  # ✅ 이름 변경 (estimated_time_min → plan_time)
 # 관계
    user = relationship("User", back_populates="plans")
    subject = relationship("Subject", back_populates="plans")
    row_plan = relationship("RowPlan", back_populates="plans")  # ✅ 양방향 연결

# plan-date, plan_time은 추후 입력하는 값들 이므로 nullable =true로 유지
# row_plan_id 유진 파일에는 안받고 있어서 추가하려면 연동된 페이지를 고쳐야해서 변경 x

# 기존 유진
'''class Plan(Base):
    __tablename__ = "plan"

    plan_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))
    subject_id = Column(Integer, ForeignKey("subject.subject_id", ondelete="CASCADE"))
    plan_name = Column(String(255))
    plan_date = Column(Date, nullable=True)
    complete = Column(Boolean, default=False)
    plan_time = Column(Integer, nullable=True) '''