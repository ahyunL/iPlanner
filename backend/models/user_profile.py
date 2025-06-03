# backend/models/user_profile.py
# 기존 user 테이블을 건드리지 않고 name, email을 따로 관리하기 위한 user_profile 서브 테이블

from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from db import Base  # 프로젝트에서 사용하는 Base 가져오기

class UserProfile(Base):
    __tablename__ = "user_profile"

    profile_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"), unique=True, nullable=False)

    name = Column(String(100), nullable=True)
    email = Column(String(100), nullable=True)

    # 🔁 역참조: User 모델에서 back_populates="profile" 필요
    user = relationship("User", back_populates="profile")