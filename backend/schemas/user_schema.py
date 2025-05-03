# backend/schemas/user_schema.py

from pydantic import BaseModel
from typing import Optional
from datetime import date

# ✅ 회원가입 요청에 사용되는 데이터 구조
class UserCreate(BaseModel):
    login_id: str            # 로그인 ID (필수)
    password: str            # 비밀번호 (필수, 서버에서 해싱)
    birthday: Optional[date] # 생일 (선택)
    phone: Optional[str]     # 전화번호 (선택)

# ✅ 로그인 요청에 사용되는 데이터 구조
class UserLogin(BaseModel):
    login_id: str
    password: str

# ✅ 회원가입 후 응답 시 반환되는 유저 정보
class UserOut(BaseModel):
    user_id: int
    login_id: str

    # SQLAlchemy 모델과 연결 가능하도록 설정
    class Config:
        from_attributes = True
