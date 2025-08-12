from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.routing import APIRoute
from routers import personal_schedule  # 상단 import

from routers import chatbot_router


# 프로젝트 루트에서 필요한 라우터 모드로 갱신
from routers import planner, row_plan, auth, user, subject, plan, handwriting, timer, pdf, user_type_router,user_study_router

# 아현추가
from routers import notifications as notifications_router
# 맨 위 import 근처 어딘가에 추가
from routers.notifications import send_notification_to_user

app = FastAPI()

# CORS 설정 (개발 중엔 모든 출처 허용)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록

app.include_router(chatbot_router.router, prefix="/api", tags=["Chatbot"]) # 챗봇

app.include_router(personal_schedule.router)  # 개인 일정 관리
app.include_router(auth.router, prefix="/auth", tags=["Auth"])         # 호신/인증 관리
app.include_router(user.router, prefix="/user", tags=["User"])         # 유저 관리
app.include_router(planner.router, prefix="/planner", tags=["Planner"]) # GPT 계획
app.include_router(row_plan.router, prefix="/row-plan", tags=["RowPlan"]) # 학습 자료 등록
app.include_router(subject.router, prefix="/subject", tags=["Subject"])    # 과도 관리
app.include_router(plan.router, prefix="/plan", tags=["Plan"])             # 학습 계획 관리
app.include_router(timer.router, prefix="/timer", tags=["Timer"])
      # 계획 저장/조회
app.include_router(pdf.router, prefix="/pdf", tags=["PDF"])     # pdf 필기기
app.mount("/static", StaticFiles(directory="static"), name="static")  

app.include_router(handwriting.router, prefix="/handwriting", tags=["Handwriting"])  # 필기
app.include_router(user_type_router.router, prefix="/user-type", tags=["UserType"]) #유저 학습유형 정보
app.include_router(user_study_router.router, tags=["StudyDaily"]) # 학습자의 공부유형 나누기 전 데이터 

# 알림 관련 아현 추가
app.include_router(notifications_router.router)

@app.on_event("startup")
def show_registered_routes():
    print("\n [등록된 라우터 경로 목록]")
    for route in app.routes:
        if isinstance(route, APIRoute):
            print(f"{route.path} ({route.methods})")
        else:
            print(f"{route.path} (Static or Mounted)")


# 기본 루트 경로 테스트용
@app.get("/")
def read_root():
    return {"message": "AI Planner API is running "}

from fastapi.openapi.utils import get_openapi

# OpenAPI 스키마 커스터마이징

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title="CapstoneEduApp",
        version="1.0.0",
        description="캡스톤 교육 프로젝트 API입니다.",
        routes=app.routes,
    )

    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT"
        }
    }

    for path in openapi_schema["paths"]:
        for method in openapi_schema["paths"][path]:
            if "security" not in openapi_schema["paths"][path][method]:
                openapi_schema["paths"][path][method]["security"] = [{"BearerAuth": []}]

    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi


@app.get("/")
def read_root():
    return {"message": "GPT Chatbot API is running!"}


# 아현이 거에서 이렇게 수정되어있었는데, 함부로 수정했다가 에러 날까봐, 경로 두가지로 놔둠. (8/12)
@app.get("/gpt") #("/")에서 수정함 
def read_root():
    return {"message": "GPT Chatbot API is running!"}


# --- 자동 알림 스케줄러 추가 시작 ---
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import date
from zoneinfo import ZoneInfo
from sqlalchemy import text

from models.notification import Notification
from db import SessionLocal

# 세션 팩토리 import (프로젝트에 맞게)
try:
    from db import SessionLocal
except Exception:
    from database import SessionLocal  # 프로젝트에 따라 이쪽일 수도 있음

KST = ZoneInfo("Asia/Seoul")
scheduler = BackgroundScheduler(timezone=str(KST))

def send_push(user_id: int, title: str, body: str):
    try:
        with SessionLocal() as db:
            row = Notification(user_id=user_id, title=title, is_read=False)

            # 모델 속성이 body인지 message인지 케이스 대응
            if hasattr(row, "body"):
                row.body = body
            elif hasattr(row, "message"):
                row.message = body
            else:
                # 혹시 둘 다 없으면 예외 처리
                raise RuntimeError("Notification model has neither 'body' nor 'message'")

            db.add(row)
            db.commit()
    except Exception as e:
        print(f"[PUSH ERROR] user={user_id} | {e}")

def _fetch_incomplete_plans(sess, target: date):
    # plan_date 가 DATE면 그대로, DATETIME이면 DATE(plan_date)=CURDATE() 로 바꿔줘.
    sql = text("""
        SELECT user_id, plan_name, plan_date
        FROM plan
        WHERE plan_date = CURDATE()
          AND complete = 0
    """)
    return sess.execute(sql).all()

def _notify_morning():
    """아침 알림: 오늘 해야 할 계획 안내"""
    with SessionLocal() as sess:
        rows = _fetch_incomplete_plans(sess, date.today())
        by_user = {}
        for user_id, plan_name, plan_date in rows:
            by_user.setdefault(user_id, []).append(plan_name)

        for uid, plans in by_user.items():
            title = "오늘 학습 계획 알림"
            body = f"오늘은 {', '.join(plans)} 하는 날이에요!"
            send_push(uid, title, body)

def _notify_last_call():
    """마감 전 독촉 알림"""
    with SessionLocal() as sess:
        rows = _fetch_incomplete_plans(sess, date.today())
        by_user = {}
        for user_id, plan_name, plan_date in rows:
            by_user.setdefault(user_id, []).append(plan_name)

        for uid, plans in by_user.items():
            title = "마감 임박! 오늘 계획을 실천해주세요"
            body = f"아직 미완료: {', '.join(plans)}"
            send_push(uid, title, body)

# 스케줄 등록 (KST 기준 09:00, 21:00)
@app.on_event("startup")
def _start_scheduler():
    scheduler.add_job(_notify_morning,  CronTrigger(hour=9,  minute=0))
    scheduler.add_job(_notify_last_call, CronTrigger(hour=21, minute=0))
    scheduler.start()
    print("[APScheduler] jobs → 09:00 / 21:00 (KST)")

@app.on_event("shutdown")
def _stop_scheduler():
    scheduler.shutdown()
# --- 자동 알림 스케줄러 추가 끝 ---

# (선택) 수동 테스트용 엔드포인트
@app.get("/debug/run-morning")
def _debug_run_morning():
    _notify_morning()
    return {"ok": True}

@app.get("/debug/run-lastcall")
def _debug_run_lastcall():
    _notify_last_call()
    return {"ok": True}