# backend/models/refresh_token.py
# ✔️ 사용자별 Refresh Token을 저장하고 관리하기 위한 SQLAlchemy 모델

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from db import Base

class RefreshToken(Base):
    """
    사용자별로 발급된 Refresh Token을 저장하는 테이블입니다.
    이 토큰은 Access Token이 만료되었을 때, 새로운 토큰을 발급받기 위해 사용됩니다.
    """

    __tablename__ = "refresh_token"  # 테이블 이름 지정

    # 고유 ID (자동 증가)
    id = Column(Integer, primary_key=True, autoincrement=True)

    # 외래키: 어떤 사용자에게 발급된 토큰인지
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))

    # 실제 JWT Refresh Token 문자열
    token = Column(String(500), nullable=False)

    # 토큰이 발급된 시각 (기록용)
    created_at = Column(DateTime, default=datetime.utcnow)

    # 토큰의 만료 시각 (자동 무효화 기준)
    expires_at = Column(DateTime)

    # 관계 설정 (User 테이블과 연결)
    user = relationship("User", back_populates="refresh_tokens")

