# models/pdf_folder.py

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from db import Base

class Folder(Base):
    __tablename__ = "folders"  # ERD 기준 테이블명

    folder_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))
    name = Column(String(255), nullable=False)  # 컬럼명 및 길이 수정
    created_at = Column(DateTime, default=datetime.utcnow)

    # 관계
    pdf_notes = relationship("PdfNote", back_populates="folder", cascade="all, delete-orphan")
    user = relationship("User", back_populates="folders")
    handwritings = relationship("Handwriting", back_populates="folder")
