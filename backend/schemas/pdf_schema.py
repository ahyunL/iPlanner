# backend/schemas/pdf_schema.py

from pydantic import BaseModel
from typing import Optional
from datetime import datetime

# ✅ [PDF 노트 생성용 요청 스키마]
class PdfNoteCreate(BaseModel):
    title: str
    folder_id: int

# ✅ [PDF 노트 조회용 응답 스키마]
class PdfNoteOut(BaseModel):
    pdf_id: int
    title: str
    file_path: str
    total_pages: int
    created_at: datetime
    updated_at: datetime
    user_id: int
    folder_id: int

    class Config:
        from_attributes = True

# ✅ [페이지 생성 요청용 스키마]
class PdfPageCreate(BaseModel):
    pdf_id: int
    page_number: int
    page_order: Optional[int] = None
    image_preview_url: Optional[str] = None

# ✅ [페이지 응답용 스키마]
class PdfPageOut(BaseModel):
    page_id: int
    pdf_id: int
    page_number: int
    page_order: Optional[int] = None
    image_preview_url: Optional[str] = None
    created_at: datetime
    aspect_ratio: Optional[float] = None  # ✅ 여기에 추가

    class Config:
        from_attributes = True

# ✅ [필기 저장 요청용 스키마]
class PdfAnnotationCreate(BaseModel):
    page_id: int
    page_number: int
    annotation_type: str
    data: dict

# ✅ [필기 응답용 스키마]
class PdfAnnotationOut(BaseModel):
    annotations_id: int
    page_id: int
    page_number: int
    annotation_type: str
    data: dict
    created_at: datetime

    class Config:
        from_attributes = True

# ✅ [폴더 생성 요청용 스키마]
class PdfFolderCreate(BaseModel):
    name: str  # ✅ 모델의 'name' 컬럼에 맞춤

# ✅ [폴더 응답용 스키마]
class PdfFolderOut(BaseModel):
    folder_id: int
    user_id: int
    name: str  # ✅ 수정됨
    created_at: datetime

    class Config:
        from_attributes = True
