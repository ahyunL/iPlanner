# backend/routers/subjects.py
# /subjects POST 등록 API
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from db import get_db
from models import subject as subject_model
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

class SubjectCreate(BaseModel):
    user_id: int
    field: str
    test_name: str
    test_date: str
    start_date: str
    end_date: str

@router.post("/subjects")
def create_subject(subject: SubjectCreate, db: Session = Depends(get_db)):
    new_subject = subject_model.Subject(**subject.dict())
    db.add(new_subject)
    db.commit()
    db.refresh(new_subject)
    return {"message": "Subject added", "subjectId": new_subject.subject_id}