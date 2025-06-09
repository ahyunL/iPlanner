# models/pdf_annotations.py

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from db import Base

class PdfAnnotation(Base):
    __tablename__ = "pdf_annotation"

    annotations_id = Column(Integer, primary_key=True, index=True)  # ERD 기준 컬럼명
    page_id = Column(Integer, ForeignKey("pdf_pages.page_id", ondelete="CASCADE"))  # FK 유지
    page_number = Column(Integer)
    annotation_type = Column(String(50))
    data = Column(JSON)  # jsonb에 해당하는 SQLAlchemy 타입
    created_at = Column(DateTime, default=datetime.utcnow)  # 생성시간 추가

    # 관계 설정
    page = relationship("PdfPage", back_populates="annotations")
