from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from db import get_db
from schemas.handwriting_schema import HandwritingCreate
from models.handwriting import Handwriting

router = APIRouter()

@router.post("/")
def create_handwriting(
    handwriting: HandwritingCreate,
    db: Session = Depends(get_db),
):
    new_handwriting = Handwriting(
        folder_id=handwriting.folder_id,
        pdf_id=handwriting.pdf_id,
        page_number=handwriting.page_number,
        x=handwriting.x,
        y=handwriting.y,
        stroke_type=handwriting.stroke_type,
        color=handwriting.color,
        thickness=handwriting.thickness
    )
    db.add(new_handwriting)
    db.commit()
    db.refresh(new_handwriting)
    return {"message": "필기 저장 완료", "id": new_handwriting.handwriting_id}
