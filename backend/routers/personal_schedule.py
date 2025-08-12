from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models.personal_schedule import PersonalSchedule
from models.user import User
from schemas.personal_schedule import PersonalScheduleCreate, PersonalScheduleUpdate, PersonalScheduleOut
from utils.auth import get_current_user
from typing import List
from datetime import date

router = APIRouter(
    prefix="/personal-schedule",
    tags=["PersonalSchedule"]
)

@router.post("/", response_model=PersonalScheduleOut)
def create_schedule(schedule: PersonalScheduleCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    new_schedule = PersonalSchedule(
        user_id=user.user_id,
        title=schedule.title,
        date=schedule.date,
        color=schedule.color
    )
    db.add(new_schedule)
    db.commit()
    db.refresh(new_schedule)
    return new_schedule

@router.get("/today", response_model=List[PersonalScheduleOut])
def get_today_schedules(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    today = date.today()
    return db.query(PersonalSchedule).filter_by(user_id=user.user_id, date=today).all()

@router.get("/by-date", response_model=List[PersonalScheduleOut])
def get_schedules_by_date(date: date, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return db.query(PersonalSchedule).filter_by(user_id=user.user_id, date=date).all()

@router.put("/{schedule_id}", response_model=PersonalScheduleOut)
def update_schedule(schedule_id: int, updated: PersonalScheduleUpdate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    schedule = db.query(PersonalSchedule).filter_by(id=schedule_id, user_id=user.user_id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
    schedule.title = updated.title
    schedule.date = updated.date
    schedule.color = updated.color
    db.commit()
    db.refresh(schedule)
    return schedule

@router.delete("/{schedule_id}")
def delete_schedule(schedule_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    schedule = db.query(PersonalSchedule).filter_by(id=schedule_id, user_id=user.user_id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
    db.delete(schedule)
    db.commit()
    return {"message": "삭제 완료"}