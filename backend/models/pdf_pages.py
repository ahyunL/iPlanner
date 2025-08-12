# models/pdf_pages.py


from sqlalchemy import Column, Integer, Text, ForeignKey, DateTime, Float  # ✅ Float 추가
from sqlalchemy.orm import relationship
from datetime import datetime
from db import Base

class PdfPage(Base):
    __tablename__ = "pdf_pages"  # ✅ ERD에 맞춰 테이블명 수정

    page_id = Column(Integer, primary_key=True, index=True)
    pdf_id = Column(Integer, ForeignKey("pdf_notes.pdf_id", ondelete="CASCADE"))
    page_number = Column(Integer)
    page_order = Column(Integer)
    image_preview_url = Column(Text)  # ✅ 타입: text (ERD 기준)
    aspect_ratio = Column(Float, nullable=True)  # ✅ 새로 추가된 비율 필드
    created_at = Column(DateTime, default=datetime.utcnow)  # ✅ 생성일자 추가

    # 관계
    note = relationship("PdfNote", back_populates="pages")
    annotations = relationship("PdfAnnotation", back_populates="page", cascade="all, delete-orphan")


# from sqlalchemy import Column, Integer, String, ForeignKey
# from sqlalchemy.orm import relationship
# from db import Base

# class PdfPage(Base):
#     __tablename__ = "pdf_page"

#     page_id = Column(Integer, primary_key=True, index=True)
#     pdf_id = Column(Integer, ForeignKey("pdf_note.note_id", ondelete="CASCADE"))
#     page_number = Column(Integer)
#     page_order = Column(Integer)
#     image_preview_url = Column(String(255))

#     note = relationship("PdfNote", back_populates="pages")
#     annotations = relationship("PdfAnnotation", back_populates="page", cascade="all, delete-orphan")