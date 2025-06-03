from sqlalchemy import Column, Integer, ForeignKey, Date
from sqlalchemy.orm import relationship
from db import Base

class Timer(Base):
    __tablename__ = "timer"

    timer_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("user.user_id"), nullable=False)
    study_date = Column(Date, nullable=False)
    total_minutes = Column(Integer, default=0)

    user = relationship("User", back_populates="timers")
