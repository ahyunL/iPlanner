# yuminsu
# 📖 iPlanner
**스마트 학습 관리 앱 – 공부 시간 추적부터 계획 관리, 자동 분석까지 한 번에!**

---

##  프로젝트 소개
iPlanner는 사용자의 공부 습관을 분석하고 맞춤 피드백을 제공하는 **학습 관리 앱**입니다.  
타이머, 캘린더, 플래너 기능을 통합하여 **효율적인 자기주도 학습**을 돕습니다.  

---

##  주요 기능
- **스터디 타이머**: 실시간 학습 기록 & 백엔드 연동  
- **캘린더/플래너**: 학습 계획을 주간·월간 단위로 시각화  
- **마이페이지 분석**: TimesNet 기반 성향 분석 (성실도/반복형/시간대)  
- **알림 기능**: 계획 실행 독촉, 학습 완료 축하 메시지  
- **PDF 필기 & 노트**: 강의 자료 위에 직접 필기
- **챗봇(RAG)**: 업로드한 PDF에서 내용 검색·요약·질문 응답  

---

##  기술 스택
- **Frontend**: Flutter (Provider 상태 관리, PageView, Drawer Navigation)  
- **Backend**: FastAPI, SQLAlchemy, Alembic  
- **Database**: MySQL  
- **AI**: XGBoost, PyTorch  

---

##  프로젝트 구조
```text
iplanner/
├─ ERD/                         # DB ERD 다이어그램
├─ backend/                     # FastAPI 백엔드
│  ├─ alembic/                  # DB 마이그레이션 관리
│  ├─ models/                   # SQLAlchemy 모델 정의
│  ├─ routers/                  # API 라우터 (엔드포인트)
│  ├─ schemas/                  # Pydantic 스키마
│  ├─ services/                 # 비즈니스 로직
│  ├─ static/                   # 정적 파일
│  ├─ utils/                    # 유틸 함수
│  ├─ .venv/                    # (로컬) 가상환경 - 배포 제외 권장
│  ├─ venv/                     # (로컬) 가상환경 - 배포 제외 권장
│  ├─ alembic.ini               # Alembic 설정
│  ├─ config.py                 # 환경 설정
│  ├─ db.py                     # DB 연결 설정
│  ├─ main.py                   # FastAPI 엔트리포인트
│  ├─ requirements.txt          # Python 의존성
│  ├─ schedule_plan.py          # 학습 계획 스케줄 코드
│  └─ test.db                   # SQLite 테스트 DB
│
├─ frontend/                    # Flutter 프론트엔드
│  ├─ android/                  # Android 빌드 설정
│  ├─ assets/                   # 이미지/폰트 등 리소스
│  ├─ ios/                      # iOS 빌드 설정
│  ├─ lib/                      # Flutter 핵심 코드
│  ├─ linux/                    # Linux 빌드
│  ├─ macos/                    # macOS 빌드
│  ├─ web/                      # Web 빌드
│  ├─ windows/                  # Windows 빌드
│  ├─ test/                     # Flutter 테스트
│  ├─ pubspec.yaml              # Flutter 의존성 설정
│  ├─ pubspec.lock
│  ├─ analysis_options.yaml     # Dart 분석 옵션
│  ├─ .gitignore
│  └─ .metadata
│
├─ .idea/                       # IDE 설정
├─ .gitignore                   # Git ignore 규칙
└─ README.md                    # 프로젝트 문서
