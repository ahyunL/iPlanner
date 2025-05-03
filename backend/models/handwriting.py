# backend/models/handwriting.py

from sqlalchemy import Column, Integer, Float, String, ForeignKey
from sqlalchemy.orm import relationship
from db import Base  # Base 임포트
from models.folder_model import Folder  # 올바른 임포트 경로

class Handwriting(Base):
    __tablename__ = "handwriting"

    handwriting_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"))
    folder_id = Column(Integer, ForeignKey("folder.folder_id", ondelete="CASCADE"))
   # pdf_id = Column(Integer, ForeignKey("pdf.pdf_id", ondelete="CASCADE"))

    page_number = Column(Integer)  # 몇 페이지 위에 썼는지
    x = Column(Float)              # 좌표 정보
    y = Column(Float)
    stroke_type = Column(String, default="pen")  # 펜, 형광펜 등
    color = Column(String, default="#000000")    # 필기 색상
    thickness = Column(Float, default=1.0)

    user = relationship("User", back_populates="handwritings")
    folder = relationship("folder_model.Folder", back_populates="handwritings")  # 변경된 폴더명에 맞게 수정

   # pdf = relationship("PDF", back_populates="handwritings")
