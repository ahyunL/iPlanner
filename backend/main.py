from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


# 📦 라우터 모듈 import
from routers import planner, row_plan, auth, user, subject, plan, handwriting

app = FastAPI()

# ✅ CORS 설정 (개발 중엔 "*" 허용, 운영 시에는 도메인 제한 권장)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 출처 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ 라우터 등록 (기능별 prefix + 태그 설정)
app.include_router(auth.router, prefix="/auth", tags=["Auth"])         # 🔐 인증: 로그인, 토큰 재발급, 로그아웃
app.include_router(user.router, prefix="/auth", tags=["user"])        # 👤 유저 회원가입 등
app.include_router(planner.router, prefix="/planner", tags=["Planner"])# 🧠 AI 계획 생성
app.include_router(row_plan.router, prefix="/row-plan", tags=["RowPlan"])  # 📚 학습자료 등록/조회
app.include_router(subject.router, prefix="/subject", tags=["Subject"])    # 📘 과목 등록/조회
app.include_router(plan.router, prefix="/plan", tags=["Plan"])             # 🗓️ 계획 저장/조회

from routers import handwriting  # handwriting 라우터를 import 해야 해.

app.include_router(handwriting.router)  # 라우터 연결

# ✅ 기본 루트 경로 테스트용
@app.get("/")
def read_root():
    return {"message": "AI Planner API is running 🧠"}



from fastapi.openapi.utils import get_openapi

# 🔧 FastAPI의 기본 OpenAPI 스키마를 커스터마이징하는 함수 정의
def custom_openapi():
    # 이미 캐싱된 스키마가 있다면 그대로 반환
    if app.openapi_schema:
        return app.openapi_schema

    # 기존 FastAPI 스키마 불러오기
    openapi_schema = get_openapi(
        title="CapstoneEduApp",  # API 제목
        version="1.0.0",         # 버전
        description="캡스톤 교육 프로젝트 API입니다.",  # 설명
        routes=app.routes,       # 앱의 라우팅 정보 포함
    )

    # 🔐 Swagger UI에서 Bearer Token 입력창을 표시하기 위한 보안 스키마 정의
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {                    # 스키마 이름 (임의 설정 가능)
            "type": "http",                # HTTP 인증 방식
            "scheme": "bearer",            # 스킴은 bearer로 고정
            "bearerFormat": "JWT"          # 포맷은 JWT로 명시 (Swagger UI에서 설명용)
        }
    }

    # 모든 path + method 조합에 보안 설정 추가 → 🔐 입력창 연동
    for path in openapi_schema["paths"]:
        for method in openapi_schema["paths"][path]:
            if "security" not in openapi_schema["paths"][path][method]:
                openapi_schema["paths"][path][method]["security"] = [{"BearerAuth": []}]

    # 커스터마이징된 스키마를 FastAPI 앱에 캐싱
    app.openapi_schema = openapi_schema
    return app.openapi_schema

# 💡 FastAPI의 openapi() 함수를 우리가 정의한 함수로 교체
app.openapi = custom_openapi
