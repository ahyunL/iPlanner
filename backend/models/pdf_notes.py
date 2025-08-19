# models/pdf_notes.py
from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from db import Base

class PdfNote(Base):
    __tablename__ = "pdf_notes"  # ERD 기준 테이블명

    pdf_id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255))      # 길이 수정
    file_path = Column(Text)         # 타입 수정
    total_pages = Column(Integer)
    aspect_ratio = Column(Float, nullable=True)  # 추가: 첫 페이지의 가로/세로 비율

    created_at = Column(DateTime, default=datetime.utcnow)  # 생성일자
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)  # 수정일자

    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))
    folder_id = Column(Integer, ForeignKey("folders.folder_id", ondelete="CASCADE"))

    # 관계
    folder = relationship("Folder", back_populates="pdf_notes")
    user = relationship("User", back_populates="pdf_notes")
    pages = relationship("PdfPage", back_populates="note", cascade="all, delete-orphan")


