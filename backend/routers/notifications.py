from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List
from sqlalchemy import func #ah 추가
from sqlalchemy import text #ah 추가

from db import get_db
from utils.auth import get_current_user
from models import user as user_model
from models.notification import Notification
from schemas.notification_schema import NotificationOut, NotificationCreate, IdsIn

router = APIRouter(prefix="/notifications", tags=["notifications"])

@router.get("/", response_model=List[NotificationOut])
def list_notifications(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user),
):
    rows = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.user_id)
        .order_by(desc(Notification.created_at), desc(Notification.notification_id))
        .offset(offset)
        .limit(limit)
        .all()
    )
    return rows

@router.post("/", response_model=NotificationOut)
def create_notification(
    payload: NotificationCreate,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user),
):
    row = Notification(
        user_id=current_user.user_id,
        title=payload.title,
        body=payload.body,
        is_read=False,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row

@router.put("/read")
def mark_read(
    ids_in: IdsIn,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user),
):
    if not ids_in.ids:
        return {"updated": 0}

    q = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.user_id)
        .filter(Notification.notification_id.in_(ids_in.ids))
    )
    updated = q.update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    return {"updated": updated}

@router.put("/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user),
):
    q = db.query(Notification).filter(Notification.user_id == current_user.user_id)
    updated = q.update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    return {"updated": updated}

@router.delete("/{notification_id}")
def delete_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user),
):
    row = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.user_id)
        .filter(Notification.notification_id == notification_id)
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    db.delete(row)
    db.commit()
    return {"deleted": notification_id}

# --- 스케줄러/내부 호출용 헬퍼 함수 추가 ---
from db import SessionLocal
from models.notification import Notification

def send_notification_to_user(user_id: int, title: str, body: str) -> int:
    """
    인증 컨텍스트 없이도 직접 DB에 알림을 저장하는 내부용 함수.
    스케줄러(APS)에서 호출합니다.
    """
    with SessionLocal() as db:
        row = Notification(
            user_id=user_id,
            title=title,
            body=body,
            is_read=False,
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return row.notification_id

@router.get("/unread-count")
def unread_count(
    db: Session = Depends(get_db),
    current_user: user_model.User = Depends(get_current_user),
):
    """
    현재 사용자 미읽음 알림 개수 (raw SQL로 안전하게)
    """
    try:
        # is_read 는 TINYINT(1) 이므로 0/1 비교가 가장 확실
        sql = text("""
            SELECT COUNT(*) AS cnt
            FROM notifications
            WHERE user_id = :uid AND is_read = 0
        """)
        cnt = db.execute(sql, {"uid": current_user.user_id}).scalar()
        cnt = int(cnt or 0)
        return {"unread": cnt, "count": cnt}
    except Exception as e:
        # 원인 파악용 로그 남기기 (콘솔에서 확인)
        print("[unread-count ERROR]", e)
        raise