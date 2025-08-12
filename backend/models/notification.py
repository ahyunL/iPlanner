# models/notification.py
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, func, ForeignKey
from db import Base

class Notification(Base):
    __tablename__ = "notifications"

    notification_id = Column("id", Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("user.user_id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    body = Column("message", Text, nullable=False)
    is_read = Column(Boolean, nullable=False, server_default="0")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

__all__ = ["Notification"]