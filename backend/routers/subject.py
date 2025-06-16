from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
from db import get_db
from utils.auth import get_user_id_from_token
from models.subject import Subject
from models.plan import Plan
from models.row_plan import RowPlan
from datetime import datetime

router = APIRouter()

# 과목 등록용 Pydantic 스키마
class SubjectCreate(BaseModel):
    field: str
    test_name: str
    test_date: datetime
    start_date: datetime
    end_date: datetime

# 과목 전체 리스트 조회
@router.get("/list")
def list_subjects(request: Request, db: Session = Depends(get_db)):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="토큰이 없습니다.")

    token = auth_header.split(" ")[1]
    user_id = get_user_id_from_token(token)

    subjects = db.query(Subject).filter(Subject.user_id == user_id).all()
    return subjects
# 전체 과목 리스트 반환 (로그인한 사용자 기준)
@router.get("/list")
def get_subject_list(request: Request, db: Session = Depends(get_db)):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="토큰이 없습니다.")

    token = auth_header.split(" ")[1]
    user_id = get_user_id_from_token(token)

    subjects = db.query(Subject).filter(Subject.user_id == user_id).all()
    return [
        {
            "subject_id": s.subject_id,
            "field": s.field,
            "test_name": s.test_name,
            "test_date": str(s.test_date),
            "start_date": str(s.start_date),
            "end_date": str(s.end_date)
        }
        for s in subjects
    ]

# 과목 등록
@router.post("/")
def create_subject(request: Request, subject: SubjectCreate, db: Session = Depends(get_db)):
    try:
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="토큰이 없습니다.")

        token = auth_header.split(" ")[1]
        user_id = get_user_id_from_token(token)

        new_subject = Subject(
            user_id=user_id,
            field=subject.field,
            test_name=subject.test_name,
            test_date=subject.test_date,
            start_date=subject.start_date,
            end_date=subject.end_date,
        )

        db.add(new_subject)
        db.commit()
        db.refresh(new_subject)
        return {"subject_id": new_subject.subject_id}

    except Exception as e:
        print("subject 저장 중 오류 발생:", e) 
        raise HTTPException(status_code=500, detail=f"Subject 저장 실패: {str(e)}")

# 전체 학습 데이터 삭제
@router.delete("/delete-all")
def delete_all_study_data(request: Request, db: Session = Depends(get_db)):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="토큰이 없습니다.")

    token = auth_header.split(" ")[1]
    user_id = get_user_id_from_token(token)

    db.query(Plan).filter(Plan.user_id == user_id).delete()
    db.query(RowPlan).filter(RowPlan.user_id == user_id).delete()
    db.query(Subject).filter(Subject.user_id == user_id).delete()
    db.commit()
    return {"message": "Deleted all study data for user"}


@router.delete("/{subject_id}")
def delete_single_subject(subject_id: int, request: Request, db: Session = Depends(get_db)):
    print(f"[과목 삭제 요청] subject_id: {subject_id}")

    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        print("Authorization 헤더가 없음")
        raise HTTPException(status_code=401, detail="토큰이 없습니다.")

    token = auth_header.split(" ")[1]
    user_id = get_user_id_from_token(token)
    print(f"user_id from token: {user_id}")

    # subject 검색
    subject = db.query(Subject).filter(
        Subject.subject_id == subject_id,
        Subject.user_id == user_id
    ).first()
    print(f"subject exists? {subject is not None}")

    if not subject:
        print("해당 유저의 과목이 아님 (혹은 존재하지 않음)")
        raise HTTPException(status_code=404, detail="해당 과목을 찾을 수 없습니다.")

    # 관련된 계획 삭제
    deleted_plan_count = db.query(Plan).filter(Plan.subject_id == subject_id).delete()
    deleted_row_count = db.query(RowPlan).filter(RowPlan.subject_id == subject_id).delete()
    print(f"연결된 Plan 삭제 수: {deleted_plan_count}, RowPlan 삭제 수: {deleted_row_count}")

    db.delete(subject)
    db.commit()
    print(f"과목 삭제 완료: subject_id={subject_id}")

    return {"message": f"과목 및 관련 계획이 삭제되었습니다. (subject_id={subject_id})"}

