# db.py 
#원래는 pysmsql 방식이었는데, 우리 코드 구조 자체가 FastAPI + SQLAlchemy 세션(SessionLocal) 구조여서 바꿨어요!

import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# .env 파일에서 환경변수 불러오기
load_dotenv()

# 데이터베이스 연결 URL
DATABASE_URL = os.getenv("DATABASE_URL", "mysql+pymysql://root:1204@localhost/yuminsu")

# SQLAlchemy 엔진 생성
engine = create_engine(
    DATABASE_URL,
    echo=True,  # 콘솔에 SQL 쿼리 출력 (개발할 때 유용, 배포 시 False로 변경)
    pool_pre_ping=True  # 연결 끊김 자동 감지
)

# 세션 생성기
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base 클래스 (모델들이 이걸 상속해야 함)
Base = declarative_base()

# FastAPI 의존성 주입용 DB 세션
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
