# models/user_type_history.py
from sqlalchemy import Column, Integer, String, Date, ForeignKey
from sqlalchemy.orm import relationship
from db import Base

class UserTypeHistory(Base):
    __tablename__ = "user_type_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id"), nullable=False)
    week_start_date = Column(Date, nullable=False)

    sincerity = Column(String(20), nullable=False)
    repetition = Column(String(20), nullable=False)
    timeslot = Column(String(20), nullable=False)

        # 여기에 추가
    missing_days = Column(Integer, nullable=False, default=0)

    user = relationship("User", back_populates="user_type_history")
