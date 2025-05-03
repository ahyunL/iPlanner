from sqlalchemy import Column, Integer, String
from db import Base  # Base를 임포트해야 해

class Folder(Base):
    __tablename__ = "folder"  # 테이블 이름

    folder_id = Column(Integer, primary_key=True, autoincrement=True)  # 기본 키
    name = Column(String(255), nullable=False)  # 폴더 이름 (필수)

    # 폴더에 대한 다른 필드들도 추가 가능
    # 예: created_at, updated_at 등
