# # backend/routers/user.py

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from db import get_db
from models.user import User
from models.refresh_token import RefreshToken
from schemas.user_schema import UserCreate, UserLogin, UserOut
from utils.auth import (
    hash_password, verify_password, create_access_token,
    get_current_user, delete_refresh_token_for_user, delete_expired_refresh_tokens   # ✅ 이 줄 추가!
)

router = APIRouter()


# ✅ [회원가입 API]
@router.post("/signup", response_model=UserOut)
def signup(user: UserCreate, db: Session = Depends(get_db)):
    # 기존 ID 중복 확인
    existing_user = db.query(User).filter(User.login_id == user.login_id).first()
    if existing_user:
        print(f"❌ 회원가입 실패: 이미 존재하는 ID - {user.login_id}")
        raise HTTPException(status_code=400, detail="이미 사용 중인 ID입니다.")

    # ✅ 전화번호 중복 확인 추가
    existing_phone = db.query(User).filter(User.phone == user.phone).first()
    if existing_phone:
        print(f"❌ 회원가입 실패: 이미 존재하는 전화번호 - {user.phone}")
        raise HTTPException(status_code=400, detail="이미 사용 중인 전화번호입니다.")

    new_user = User(
        login_id=user.login_id,
        password=hash_password(user.password),
        birthday=user.birthday,
        phone=user.phone
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    print(f"✅ 회원가입 성공: ID - {new_user.login_id}, user_id - {new_user.user_id}")
    return new_user



# ✅ [로그인 API]
@router.post("/login", response_model=dict)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.login_id == user.login_id).first()

    if not db_user:
        print(f"❌ 로그인 실패: 존재하지 않는 ID - {user.login_id}")
        raise HTTPException(status_code=401, detail="로그인 정보가 일치하지 않습니다.")

    if not verify_password(user.password, db_user.password):
        print(f"❌ 로그인 실패: 비밀번호 불일치 - ID: {user.login_id}")
        raise HTTPException(status_code=401, detail="로그인 정보가 일치하지 않습니다.")

    token = create_access_token({"sub": str(db_user.user_id)})
    print(f"✅ 로그인 성공: ID - {db_user.login_id}, user_id - {db_user.user_id}")
    return {"access_token": token, "token_type": "bearer"}


# ✅ [내 정보 확인 API]
@router.get("/me", response_model=UserOut)
def read_my_info(current_user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.user_id == current_user_id).first()
    if not db_user:
        print(f"❌ 사용자 정보 조회 실패: user_id - {current_user_id} 없음")
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    print(f"✅ 사용자 정보 조회 성공: user_id - {db_user.user_id}, login_id - {db_user.login_id}")
    return db_user




@router.delete("/delete")
def delete_user(current_user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.user_id == current_user_id).first()
    if not user:
        print(f"❌ 회원 탈퇴 실패: user_id - {current_user_id} 없음")
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    db.delete(user)
    db.query(RefreshToken).filter(RefreshToken.user_id == current_user_id).delete()
    db.commit()

    # ✅ 탈퇴 후에도 만료된 토큰 정리
    delete_expired_refresh_tokens(db)

    print(f"✅ 회원 탈퇴 성공: user_id - {current_user_id}")
    return {"message": "회원 탈퇴가 완료되었습니다."}


@router.post("/logout")
def logout(current_user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    # 현재 유저의 Refresh Token 삭제
    deleted = db.query(RefreshToken).filter(RefreshToken.user_id == current_user_id).delete()
    db.commit()

    # ✅ 만료된 토큰도 자동 정리
    delete_expired_refresh_tokens(db)

    if deleted:
        print(f"✅ 로그아웃 완료: user_id - {current_user_id}")
    else:
        print(f"⚠️ 로그아웃 처리: user_id - {current_user_id}의 RefreshToken 없음")
    return {"message": "로그아웃 되었습니다."}
