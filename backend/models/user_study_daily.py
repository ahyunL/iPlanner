from sqlalchemy import Column, Integer, ForeignKey, Date
from sqlalchemy.orm import relationship
from db import Base



from sqlalchemy import UniqueConstraint

class UserStudyDaily(Base):
    __tablename__ = "user_study_daily"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id"), nullable=False)
    study_date = Column(Date, nullable=False)

    total_minutes = Column(Integer, default=0)
    morning_minutes = Column(Integer, default=0)
    afternoon_minutes = Column(Integer, default=0)
    evening_minutes = Column(Integer, default=0)
    night_minutes = Column(Integer, default=0)

    repetition = Column(Integer, default=0)
    daily_achievement = Column(Integer, default=0)  # 퍼센트 단위 (0~100)

    __table_args__ = (
        UniqueConstraint('user_id', 'study_date', name='uc_user_study_date'),  
    )

    user = relationship("User", back_populates="study_daily")
