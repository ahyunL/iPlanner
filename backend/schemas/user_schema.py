# backend/schemas/user_schema.py

from pydantic import BaseModel
from typing import Optional
from datetime import date

# 회원가입 요청에 사용되는 데이터 구조
class UserCreate(BaseModel):
    login_id: str            # 로그인 ID (필수)
    password: str            # 비밀번호 (필수, 서버에서 해싱)
    birthday: Optional[date] # 생일 (선택)
    phone: Optional[str]     # 전화번호 (선택)

# 로그인 요청에 사용되는 데이터 구조
class UserLogin(BaseModel):
    login_id: str
    password: str

# 회원가입 후 응답 시 반환되는 유저 정보
class UserOut(BaseModel):
    user_id: int
    login_id: str

    # SQLAlchemy 모델과 연결 가능하도록 설정
    class Config:
        from_attributes = True


# 서브 프로필: 이름, 이메일
class UserSubProfile(BaseModel):
    name: Optional[str]
    email: Optional[str]

    class Config:
        from_attributes = True

# 마이페이지 전체 조회용: 기본 정보 + 서브 프로필 포함
class UserProfile(BaseModel):
    login_id: str
    birthday: Optional[date]
    phone: Optional[str]
    study_time_mon: Optional[int]
    study_time_tue: Optional[int]
    study_time_wed: Optional[int]
    study_time_thu: Optional[int]
    study_time_fri: Optional[int]
    study_time_sat: Optional[int]
    study_time_sun: Optional[int]
    
    # 🔹 user_profile 테이블 조인
    profile: Optional[UserSubProfile]

    class Config:
        from_attributes = True

# 비밀번호 확인용 스키마
class PasswordCheck(BaseModel):
    password: str

# 사용자 기본정보 수정용
class UserUpdate(BaseModel):
    birthday: Optional[date]=None
    phone: Optional[str]
    study_time_mon: Optional[int]
    study_time_tue: Optional[int]
    study_time_wed: Optional[int]
    study_time_thu: Optional[int]
    study_time_fri: Optional[int]
    study_time_sat: Optional[int]
    study_time_sun: Optional[int]

# 이름, 이메일 수정용 서브 스키마
class UserSubProfileUpdate(BaseModel):
    name: Optional[str]
    email: Optional[str]


# 비밀번호 변경용 (현재 비번 없이 새 비번만 받음)
class NewPasswordUpdate(BaseModel):
    new_password: str