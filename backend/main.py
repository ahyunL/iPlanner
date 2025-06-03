# 민경언니 함수 추가 (show_registered_routes)
# 라우터 등록  pdf, static 추가함
# 라우터 등록 handwriting  삭제?

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.routing import APIRoute

# 프로젝트 루트에서 필요한 라우터 모드로 갱신
from routers import planner, row_plan, auth, user, subject, plan, handwriting, timer, pdf

app = FastAPI()

# ✅ CORS 설정 (개발 중엔 모든 출처 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ 라우터 등록
app.include_router(auth.router, prefix="/auth", tags=["Auth"])         # 호신/인증 관리
app.include_router(user.router, prefix="/user", tags=["User"])         # 유저 관리
app.include_router(planner.router, prefix="/planner", tags=["Planner"]) # GPT 계획
app.include_router(row_plan.router, prefix="/row-plan", tags=["RowPlan"]) # 학습 자료 등록
app.include_router(subject.router, prefix="/subject", tags=["Subject"])    # 과도 관리
app.include_router(plan.router, prefix="/plan", tags=["Plan"])             # 학습 계획 관리
app.include_router(timer.router, prefix="/timer", tags=["Timer"])
      # 🗓️ 계획 저장/조회
app.include_router(pdf.router, prefix="/pdf", tags=["PDF"])     # pdf 필기기
app.mount("/static", StaticFiles(directory="static"), name="static")  # ✅ 반드시 있어야 함

app.include_router(handwriting.router, prefix="/handwriting", tags=["Handwriting"])  # 필기
@app.on_event("startup")
def show_registered_routes():
    print("\n📢 [등록된 라우터 경로 목록]")
    for route in app.routes:
        if isinstance(route, APIRoute):
            print(f"{route.path} ({route.methods})")
        else:
            print(f"{route.path} (Static or Mounted)")


# ✅ 기본 루트 경로 테스트용
@app.get("/")
def read_root():
    return {"message": "AI Planner API is running 🤠"}

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
