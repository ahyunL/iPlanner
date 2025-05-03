# backend/utils/auth.py

from passlib.context import CryptContext
from datetime import datetime, timedelta
from jose import jwt, JWTError
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from db import get_db
from models.refresh_token import RefreshToken
import os
from dotenv import load_dotenv
from fastapi import Request  # 추가

# ✅ 환경 변수 로드 (.env에서 SECRET_KEY 정의 필요)
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("환경 변수 SECRET_KEY가 설정되지 않았습니다! .env 파일을 확인하세요.")
ALGORITHM = "HS256"

# ✅ 토큰 만료 시간 설정
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 15  # Access Token: 15분
REFRESH_TOKEN_EXPIRE_DAYS = 14         # Refresh Token: 14일

# ✅ 비밀번호 해싱 설정
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 🔐 비밀번호 해시 생성
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

# 🔐 평문 비밀번호와 해시 비교
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

# 🔑 Access Token 생성 함수
def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# 🔁 Refresh Token 생성 함수 (유효기간 함께 반환)
def create_refresh_token(data: dict, expires_delta: timedelta = None):
    expire = datetime.utcnow() + (expires_delta or timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS))
    to_encode = data.copy()
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM), expire

# 🗃️ DB에 Refresh Token 저장
def store_refresh_token_in_db(user_id: int, token: str, expires_at: datetime, db: Session):
    try:
        db_token = db.query(RefreshToken).filter(RefreshToken.token == token).first()
        if db_token:
            raise HTTPException(status_code=400, detail="이미 존재하는 Refresh Token입니다.")
        db_token = RefreshToken(user_id=user_id, token=token, expires_at=expires_at)
        db.add(db_token)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="DB 저장 오류: " + str(e))

# 🧹 Refresh Token 단일 삭제 (토큰 기반)
def delete_refresh_token(token: str, db: Session):
    try:
        db_token = db.query(RefreshToken).filter(RefreshToken.token == token).first()
        if not db_token:
            raise HTTPException(status_code=404, detail="해당 토큰이 존재하지 않습니다.")
        db.delete(db_token)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="DB 삭제 오류: " + str(e))

# 🔄 만료된 Refresh Token 자동 정리
def delete_expired_refresh_tokens(db: Session):
    now = datetime.utcnow()
    expired_tokens = db.query(RefreshToken).filter(RefreshToken.expires_at < now).all()
    for token in expired_tokens:
        db.delete(token)
    db.commit()

# ❌ 유저 ID 기준 Refresh Token 전체 삭제 (로그아웃 또는 탈퇴 시)
def delete_refresh_token_for_user(user_id: int, db: Session):
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
    db.commit()

# ✅ Refresh Token 유효성 검증 + DB 확인
def verify_refresh_token(token: str, db: Session) -> int:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))
    except JWTError:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
    
    db_token = db.query(RefreshToken).filter(RefreshToken.token == token).first()
    if not db_token:
        raise HTTPException(status_code=401, detail="토큰이 만료되었거나 삭제되었습니다.")
    return user_id

# 🔐 보호된 API에서 현재 로그인한 사용자 ID 추출 (Access Token 기반)
def get_current_user(request: Request) -> int:
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization 헤더가 없습니다.")

    token = auth_header[len("Bearer "):]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))
        print(f"✅ Access Token 인증 성공: user_id - {user_id}")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="토큰이 유효하지 않습니다.")

# ✅ Access Token 문자열에서 user_id 추출 (로그아웃용 등)
def get_user_id_from_token(token: str) -> int:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
