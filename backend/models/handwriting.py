# backend/models/handwriting.py

from sqlalchemy import Column, Integer, Float, String, ForeignKey
from sqlalchemy.orm import relationship
from db import Base  # Base 임포트
from models.pdf_folder import Folder  # 올바른 임포트 경로
from sqlalchemy import Column, Integer, Float, String, ForeignKey, BigInteger

class Handwriting(Base):
    __tablename__ = "handwriting"

    handwriting_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))
   # pdf_id = Column(Integer, ForeignKey("pdf.pdf_id", ondelete="CASCADE"))
    folder_id = Column(Integer, ForeignKey("folders.folder_id"))

    page_number = Column(Integer)  # 몇 페이지 위에 썼는지
    x = Column(Float)              # 좌표 정보
    y = Column(Float)
    stroke_type = Column(String(20), default="pen")  # 펜, 형광펜 등
    color = Column(String(20), default="#000000")    # 필기 색상
    thickness = Column(Float, default=1.0)

    user = relationship("User", back_populates="handwritings")
    folder = relationship("Folder", back_populates="handwritings")  # 변경된 폴더명에 맞게 수정

   # pdf = relationship("PDF", back_populates="handwritings")
