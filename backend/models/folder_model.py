
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship
from db import Base

class Folder(Base):
    __tablename__ = "folder"

    folder_id = Column(Integer, primary_key=True, index=True)
    folder_name = Column(String, index=True)

    # Handwriting 모델과의 관계 설정
    handwritings = relationship("Handwriting", back_populates="folder")
