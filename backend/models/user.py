from sqlalchemy import Column, Integer, String, Date
from sqlalchemy.orm import relationship
from db import Base

class User(Base):
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

    folders = relationship("Folder", back_populates="user", cascade="all, delete-orphan")
    pdf_notes = relationship("PdfNote", back_populates="user", cascade="all, delete-orphan")
    subjects = relationship("Subject", back_populates="user", cascade="all, delete-orphan")
    plans = relationship("Plan", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")

    handwritings = relationship("Handwriting", back_populates="user") #없는 파일이 될 수도
    timers = relationship("Timer", back_populates="user", cascade="all, delete-orphan")
    row_plans = relationship("RowPlan", back_populates="user", cascade="all, delete-orphan")

    #마이페이지 추가 정보 때문에 추가
    profile = relationship("UserProfile", uselist=False, back_populates="user", cascade="all, delete-orphan")
    user_id = Column(Integer, primary_key=True, autoincrement=True)
    # models/user.py
    user_type_history = relationship("UserTypeHistory", back_populates="user")
    # models/user.py (User 클래스 안에)
    study_daily = relationship("UserStudyDaily", back_populates="user")

    
# ✅ 반드시 마지막 줄에 Timer import 추가 (순환 참조 방지)
from models.timer import Timer



#민경언니
'''class User(Base):
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

    folders = relationship("Folder", back_populates="user", cascade="all, delete-orphan")
    pdf_notes = relationship("PdfNote", back_populates="user", cascade="all, delete-orphan")
    subjects = relationship("Subject", back_populates="user", cascade="all, delete-orphan")
    row_plans = relationship("RowPlan", back_populates="user", cascade="all, delete-orphan")
    plans = relationship("Plan", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")


'''