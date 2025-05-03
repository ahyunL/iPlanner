from sqlalchemy import Column, Integer, String, Date
from sqlalchemy.orm import relationship  # relationship 임포트
from db import Base  # Base를 임포트해야 함!

class User(Base):  # Base를 상속받음
    __tablename__ = "user"

    user_id = Column(Integer, primary_key=True, autoincrement=True)
    login_id = Column(String(20), unique=True, nullable=False)
    password = Column(String(255), nullable=False)
    birthday = Column(Date)
    phone = Column(String(15))
    study_time_mon = Column(Integer)
    study_time_tue = Column(Integer)
    study_time_wed = Column(Integer)
    study_time_thu = Column(Integer)
    study_time_fri = Column(Integer)
    study_time_sat = Column(Integer)
    study_time_sun = Column(Integer)

    # 핸드라이팅과의 관계 정의 (1:N)
    handwritings = relationship("Handwriting", back_populates="user")  # 추가
