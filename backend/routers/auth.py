from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from schemas.user_schema import UserLogin
from models.user import User
from utils.auth import create_access_token, verify_password, verify_refresh_token, delete_refresh_token

router = APIRouter()

# 로그인
@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    print(f"Received login request: {user.login_id}, {user.password}")  # 데이터 확인용
    db_user = db.query(User).filter(User.login_id == user.login_id).first()
    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(status_code=401, detail="로그인 정보가 일치하지 않습니다.")
    token = create_access_token({"sub": str(db_user.user_id)})
    print(f"✅ Access Token: {token}")  # 콘솔에 표시
    return {"access_token": token, "token_type": "bearer"}

# Refresh Token 재발급
@router.post("/refresh")
def refresh_access_token(refresh_token: str, db: Session = Depends(get_db)):
    user_id = verify_refresh_token(refresh_token, db)
    new_access_token = create_access_token({"sub": str(user_id)})
    return {"access_token": new_access_token, "token_type": "bearer"}

# 로그아웃
@router.post("/logout")
def logout(refresh_token: str, db: Session = Depends(get_db)):
    user_id = verify_refresh_token(refresh_token, db)
    delete_refresh_token(refresh_token, db)
    return {"message": "성공적으로 로그아웃되었습니다."}