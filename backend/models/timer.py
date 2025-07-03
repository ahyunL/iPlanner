from sqlalchemy import Column, Integer, ForeignKey, Date, DateTime  # DateTime 추가
from sqlalchemy.orm import relationship
from db import Base

class Timer(Base):
    __tablename__ = "timer"

    timer_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("user.user_id"), nullable=False)
    study_date = Column(Date, nullable=False)
    total_minutes = Column(Integer, default=0)

    # 25.7.2 타이머 공부시간 확장 이유로 추가.
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="timers")
