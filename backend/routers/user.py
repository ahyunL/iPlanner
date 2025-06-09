from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from db import get_db
from models.user import User
from models.user_profile import UserProfile as UserProfileModel
from models.refresh_token import RefreshToken
from schemas.user_schema import UserCreate, UserLogin, UserOut, UserProfile, PasswordCheck, UserUpdate, UserSubProfileUpdate, NewPasswordUpdate
from utils.auth import (
    hash_password, verify_password, create_access_token,
    get_current_user, delete_refresh_token_for_user, delete_expired_refresh_tokens
)

router = APIRouter()

# [회원가입 API]
@router.post("/signup", response_model=UserOut)
def signup(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.login_id == user.login_id).first()
    if existing_user:
        print(f"회원가입 실패: 이미 존재하는 ID - {user.login_id}")
        raise HTTPException(status_code=400, detail="이미 사용 중인 ID입니다.")

    existing_phone = db.query(User).filter(User.phone == user.phone).first()
    if existing_phone:
        print(f"회원가입 실패: 이미 존재하는 전화번호 - {user.phone}")
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

    print(f"회원가입 성공: ID - {new_user.login_id}, user_id - {new_user.user_id}")
    return new_user

# [로그인 API]
@router.post("/login", response_model=dict)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.login_id == user.login_id).first()

    if not db_user:
        print(f"로그인 실패: 존재하지 않는 ID - {user.login_id}")
        raise HTTPException(status_code=401, detail="로그인 정보가 일치하지 않습니다.")

    if not verify_password(user.password, db_user.password):
        print(f"로그인 실패: 비밀번호 불일치 - ID: {user.login_id}")
        raise HTTPException(status_code=401, detail="로그인 정보가 일치하지 않습니다.")

    token = create_access_token({"sub": str(db_user.user_id)})
    print(f"로그인 성공: ID - {db_user.login_id}, user_id - {db_user.user_id}")
    return {"access_token": token, "token_type": "bearer"}

# [내 정보 확인 API]
@router.get("/me", response_model=UserOut)
def read_my_info(current_user: User = Depends(get_current_user)):
    print(f"사용자 정보 조회 성공: user_id - {current_user.user_id}, login_id - {current_user.login_id}")
    return current_user


# [회원 탈퇴 API]
@router.delete("/delete")
def delete_user(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db.delete(current_user)
    db.query(RefreshToken).filter(RefreshToken.user_id == current_user.user_id).delete()
    db.commit()

    delete_expired_refresh_tokens(db)

    print(f"회원 탈퇴 성공: user_id - {current_user.user_id}")
    return {"message": "회원 탈퇴가 완료되었습니다."}

# [로그아웃 API]
@router.post("/logout")
def logout(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    deleted = db.query(RefreshToken).filter(RefreshToken.user_id == current_user.user_id).delete()
    db.commit()

    delete_expired_refresh_tokens(db)

    if deleted:
        print(f"로그아웃 완료: user_id - {current_user.user_id}")
    else:
        print(f"로그아웃 처리: user_id - {current_user.user_id}의 RefreshToken 없음")
    return {"message": "로그아웃 되었습니다."}

# [요일별 공부시간 조회 API]
@router.get("/study-time")
def get_user_study_time(current_user: User = Depends(get_current_user)):
    return {
        "mon": current_user.study_time_mon or 0,
        "tue": current_user.study_time_tue or 0,
        "wed": current_user.study_time_wed or 0,
        "thu": current_user.study_time_thu or 0,
        "fri": current_user.study_time_fri or 0,
        "sat": current_user.study_time_sat or 0,
        "sun": current_user.study_time_sun or 0,
    }

# [유저 프로필 조회 API]
@router.get("/profile", response_model=UserProfile)
def get_full_profile(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).options(joinedload(User.profile)).filter(User.user_id == current_user.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return user

# [마이페이지 정보수정 시 비밀번호 확인용 API]
@router.post("/verify-password")
def verify_password_before_update(
    check: PasswordCheck,
    current_user: User = Depends(get_current_user)
):
    if not verify_password(check.password, current_user.password):
        raise HTTPException(status_code=401, detail="비밀번호가 일치하지 않습니다.")
    return {"message": "비밀번호 확인 성공"}


# [사용자 기본 정보 수정 API]
@router.patch("/update")
def update_user_profile(
    update_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    print("수신된 사용자 수정 데이터:", update_data.dict(exclude_unset=True)) 
    for field, value in update_data.dict(exclude_unset=True).items():
        setattr(current_user, field, value)
    db.commit()
    return {"message": "사용자 정보가 수정되었습니다."}


# [서브 프로필 정보 수정 API]
@router.patch("/profile-update")
def update_user_sub_profile(
    update_data: UserSubProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    print(f"수신된 이름(raw): {update_data.name}") 
    if not current_user.profile:
        from models.user_profile import UserProfile as UserProfileModel
        current_user.profile = UserProfileModel(user_id=current_user.user_id)

    for field, value in update_data.dict(exclude_unset=True).items():
        setattr(current_user.profile, field, value)

    db.commit()
    return {"message": "이름/이메일이 수정되었습니다."}


@router.patch("/change-password")
def change_password(
    pw_data: NewPasswordUpdate,                     
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 새 비밀번호를 해시하여 저장
    current_user.password = hash_password(pw_data.new_password)
    db.commit()

    return {"message": "비밀번호가 성공적으로 변경되었습니다."}
