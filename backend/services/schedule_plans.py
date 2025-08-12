import os
from datetime import datetime, timedelta, date
from collections import defaultdict
from dotenv import load_dotenv
from db import SessionLocal
from models.user import User
from models.subject import Subject
from models.plan import Plan
import re

load_dotenv()

# 날짜 → 요일 맵 생성
def get_date_weekday_map(start_date: str, end_date: str) -> dict:
    date_map = {}
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")
    current = start
    while current <= end:
        weekday = current.strftime("%a").lower()[:3]
        date_map[current.strftime("%Y-%m-%d")] = weekday
        current += timedelta(days=1)
    return date_map


# --- 보조: plan_name에서 "n주차" 정수 추출 (없으면 None) -----------------
_week_pat = re.compile(r'(\d+)\s*주차')

def _extract_week_no(plan_name: str):
    m = _week_pat.search(plan_name or "")
    return int(m.group(1)) if m else None


# ✅ 순차(단조증가) 배정 로직
# - 같은 과목 내에서 계획을 "회차(주차) → plan_id" 순으로 정렬
# - 과목별 가능한 날짜 리스트를 앞에서부터 훑으며, 해당 요일 허용 공부시간 내에서 가장 이른 날짜를 배정
# - 꽉 찼으면 다음 날로 이월 (끝까지 못 찾으면 가장 가까운 날에 강제 배정)
def get_plan_schedule_from_gpt(data: dict) -> list:
    user_info = data["users"][0]
    study_time_by_weekday = user_info["study_time"]           # {'mon': 60, ...}
    date_weekday_map = data["date_weekday_map"]               # {'2025-08-08': 'fri', ...}

    # 과목별 사용가능 날짜(문자열) 수집 및 정렬
    subject_date_ranges = defaultdict(list)
    for subj in data["subjects"]:
        sid = subj["subject_id"]
        start = subj["start_date"]
        end = subj["end_date"]
        # date_weekday_map에 이미 모든 날짜가 있으므로 필터만 적용
        for d, _wd in date_weekday_map.items():
            if start <= d <= end:
                subject_date_ranges[sid].append(d)

    for sid in subject_date_ranges:
        subject_date_ranges[sid].sort()  # 문자열 YYYY-MM-DD 정렬 == 날짜 오름차순

    # 과목별 계획 묶기 + 정렬(주차 우선, 없으면 plan_id)
    plans_by_subject = defaultdict(list)
    for p in data["plans"]:
        plans_by_subject[p["subject_id"]].append(p)

    for sid in plans_by_subject:
        plans_by_subject[sid].sort(
            key=lambda p: (
                _extract_week_no(p.get("plan_name", "")) if _extract_week_no(p.get("plan_name", "")) is not None else 1_000_000,
                p["plan_id"]
            )
        )

    # 날짜별 누적 사용시간
    used_time_by_date = defaultdict(int)

    results = []
    # 과목 단위로 순차 배정
    for sid, plans in plans_by_subject.items():
        candidate_dates = subject_date_ranges.get(sid, [])
        if not candidate_dates:
            print(f"⛔ subject {sid}에 배정 가능한 날짜가 없습니다.")
            return [{"error": f"subject {sid}에 배정 가능한 날짜가 없습니다."}]

        # 과목 내에서 '앞에서부터' 진행하기 위한 포인터
        next_idx = 0

        for plan in plans:
            plan_id = plan["plan_id"]
            plan_time = plan["plan_time"]

            assigned = False
            # next_idx부터 끝까지 훑으며 용량 내에 들어가는 '가장 이른 날짜'를 찾는다
            for i in range(next_idx, len(candidate_dates)):
                d = candidate_dates[i]
                wd = date_weekday_map[d]          # 'mon' ...
                max_minutes = study_time_by_weekday.get(wd, 0)
                if used_time_by_date[d] + plan_time <= max_minutes:
                    results.append({"plan_id": plan_id, "plan_date": d})
                    used_time_by_date[d] += plan_time
                    # 다음 계획은 최소 이 다음날부터 보게 됨 (단조 증가)
                    next_idx = i + 1
                    assigned = True
                    break

            # 모든 남은 날짜가 꽉 찼다면: 가장 가까운 날(= next_idx 위치의 날짜 또는 마지막)을 선택해 강제 배정
            if not assigned:
                # next_idx가 범위를 벗어나면 마지막 날에 붙인다
                fallback_i = min(next_idx, len(candidate_dates) - 1)
                d = candidate_dates[fallback_i]
                results.append({"plan_id": plan_id, "plan_date": d})
                used_time_by_date[d] += plan_time
                next_idx = min(fallback_i + 1, len(candidate_dates) - 1)

    # (선택) 전체 결과를 날짜 오름차순으로 한 번 정렬해 반환
    results.sort(key=lambda x: x["plan_date"])
    return results


# 사용자, 과목, 계획 가져오기
def fetch_user_data(db, user_id):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        return None, [], []

    subjects = db.query(Subject).filter(Subject.user_id == user_id).all()

    completed_names_query = db.query(Plan.plan_name).filter(
        Plan.complete == True, Plan.user_id == user_id
    ).distinct()
    completed_names = {name for (name,) in completed_names_query}

    all_plans = db.query(Plan).filter(
        Plan.complete == False, Plan.user_id == user_id
    ).all()
    filtered_plans = [p for p in all_plans if p.plan_name not in completed_names]

    return user, subjects, filtered_plans


# 지난 날짜 계획 초기화
def reset_old_plan_dates(db, user_id):
    db.query(Plan).filter(
        Plan.complete == False,
        Plan.user_id == user_id
    ).update({"plan_date": None})
    db.commit()


# GPT 입력용 데이터 구성
def build_prompt_data(user, subjects, plans):
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    user_data = {
        "user_id": user.user_id,
        "study_time": {d: getattr(user, f"study_time_{d}") for d in days}
    }

    subject_list = []
    plan_list = [
        {
            "plan_id": p.plan_id,
            "user_id": p.user_id,
            "subject_id": p.subject_id,
            "plan_time": p.plan_time,
            "plan_name": p.plan_name
        } for p in plans
    ]

    all_dates = set()
    for s in subjects:
        subject_list.append({
            "subject_id": s.subject_id,
            "user_id": s.user_id,
            "start_date": s.start_date.strftime("%Y-%m-%d"),
            "end_date": s.end_date.strftime("%Y-%m-%d")
        })
        date_map = get_date_weekday_map(
            s.start_date.strftime("%Y-%m-%d"),
            s.end_date.strftime("%Y-%m-%d")
        )
        all_dates.update(date_map.items())

    date_weekday_map = {d: wd for d, wd in all_dates}

    return {
        "users": [user_data],
        "subjects": subject_list,
        "plans": plan_list,
        "date_weekday_map": date_weekday_map,
        "study_calendar": {}  # 사용 안 함
    }


# GPT 결과 반영
def apply_plan_dates(db, plan_dates):
    # 안전장치: 날짜 오름차순으로 저장
    plan_dates = sorted(
        [pd for pd in plan_dates if pd.get("plan_id") and pd.get("plan_date")],
        key=lambda x: x["plan_date"]
    )
    updated = 0
    for plan in plan_dates:
        plan_id = plan["plan_id"]
        plan_date = plan["plan_date"]
        db_plan = db.query(Plan).filter(Plan.plan_id == plan_id).first()
        if db_plan and db_plan.plan_date != plan_date:
            db_plan.plan_date = plan_date
            updated += 1
    db.commit()
    return updated


# FastAPI에서 호출할 수 있도록 하는 진입점 함수
def run_schedule_for_user(user_id: int, db):
    try:
        user, subjects, plans = fetch_user_data(db, user_id)

        if not user:
            return {"error": "해당 유저가 존재하지 않습니다."}
        elif not plans:
            return {"message": "배정할 계획이 없습니다."}

        reset_old_plan_dates(db, user_id)
        prompt_data = build_prompt_data(user, subjects, plans)
        plan_dates = get_plan_schedule_from_gpt(prompt_data)

        if plan_dates:
            if isinstance(plan_dates, list) and plan_dates and isinstance(plan_dates[0], dict) and "error" in plan_dates[0]:
                return {"warning": plan_dates[0]["error"]}
            updated_count = apply_plan_dates(db, plan_dates)
            return {"message": f"✅ 계획 {updated_count}건 날짜 배정 완료!"}
        else:
            return {"warning": "계획 날짜 배정 결과가 비어 있습니다."}

    except Exception as e:
        return {"error": str(e)}



# import os
# from datetime import datetime, timedelta, date
# from collections import defaultdict
# from dotenv import load_dotenv
# from db import SessionLocal
# from models.user import User
# from models.subject import Subject
# from models.plan import Plan

# load_dotenv()

# # 날짜 → 요일 맵 생성
# def get_date_weekday_map(start_date: str, end_date: str) -> dict:
#     date_map = {}
#     start = datetime.strptime(start_date, "%Y-%m-%d")
#     end = datetime.strptime(end_date, "%Y-%m-%d")
#     current = start
#     while current <= end:
#         weekday = current.strftime("%a").lower()[:3]
#         date_map[current.strftime("%Y-%m-%d")] = weekday
#         current += timedelta(days=1)
#     return date_map

# # 순수 파이썬 기반 스케줄링 로직 (GPT 호출 없음)
# def get_plan_schedule_from_gpt(data: dict) -> list:
#     user_info = data["users"][0]
#     study_time = user_info["study_time"]
#     date_weekday_map = data["date_weekday_map"]
#     study_calendar = data["study_calendar"]
#     used_time_by_date = defaultdict(int)

#     subject_date_ranges = defaultdict(list)
#     for subj in data["subjects"]:
#         sid = subj["subject_id"]
#         start = subj["start_date"]
#         end = subj["end_date"]
#         for date_str, weekday in date_weekday_map.items():
#             if start <= date_str <= end:
#                 subject_date_ranges[sid].append(date_str)

#     for sid in subject_date_ranges:
#         subject_date_ranges[sid].sort()

#     result = []
#     plans = sorted(data["plans"], key=lambda p: p["plan_id"])

#     for plan in plans:
#         plan_id = plan["plan_id"]
#         subject_id = plan["subject_id"]
#         plan_time = plan["plan_time"]

#         candidate_dates = subject_date_ranges.get(subject_id, [])

#         # ✅ 공부량이 적은 날짜부터 정렬
#         candidate_dates.sort(key=lambda d: used_time_by_date[d])

#         assigned = False
#         for d in candidate_dates:
#             weekday = date_weekday_map[d]
#             max_time = study_time.get(weekday, 0)
#             if used_time_by_date[d] + plan_time <= max_time:
#                 result.append({"plan_id": plan_id, "plan_date": d})
#                 used_time_by_date[d] += plan_time
#                 assigned = True
#                 break

#         if not assigned:
#             # ✅ 초과되더라도 가장 덜 사용된 날짜에 그냥 배정
#             fallback_date = min(candidate_dates, key=lambda d: used_time_by_date[d], default=None)
#             if fallback_date:
#                 result.append({"plan_id": plan_id, "plan_date": fallback_date})
#                 used_time_by_date[fallback_date] += plan_time
#             else:
#                 print(f"⛔ 계획 {plan_id} 을 어떤 날짜에도 배정할 수 없습니다.")
#                 return [{"error": "모든 계획을 배정할 수 없습니다."}]

#     return result


# # 사용자, 과목, 계획 가져오기
# def fetch_user_data(db, user_id):
#     user = db.query(User).filter(User.user_id == user_id).first()
#     if not user:
#         return None, [], []

#     subjects = db.query(Subject).filter(Subject.user_id == user_id).all()

#     completed_names_query = db.query(Plan.plan_name).filter(
#         Plan.complete == True, Plan.user_id == user_id
#     ).distinct()
#     completed_names = {name for (name,) in completed_names_query}

#     all_plans = db.query(Plan).filter(
#         Plan.complete == False, Plan.user_id == user_id
#     ).all()
#     filtered_plans = [p for p in all_plans if p.plan_name not in completed_names]

#     return user, subjects, filtered_plans

# # 지난 날짜 계획 초기화
# def reset_old_plan_dates(db, user_id):
#     db.query(Plan).filter(
#         Plan.complete == False,
#         Plan.user_id == user_id
#     ).update({"plan_date": None})
#     db.commit()


# # GPT 입력용 데이터 구성
# def build_prompt_data(user, subjects, plans):
#     days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

#     user_data = {
#         "user_id": user.user_id,
#         "study_time": {d: getattr(user, f"study_time_{d}") for d in days}
#     }

#     subject_list = []
#     plan_list = [
#         {
#             "plan_id": p.plan_id,
#             "user_id": p.user_id,
#             "subject_id": p.subject_id,
#             "plan_time": p.plan_time,
#             "plan_name": p.plan_name
#         } for p in plans
#     ]

#     all_dates = set()
#     for s in subjects:
#         subject_list.append({
#             "subject_id": s.subject_id,
#             "user_id": s.user_id,
#             "start_date": s.start_date.strftime("%Y-%m-%d"),
#             "end_date": s.end_date.strftime("%Y-%m-%d")
#         })
#         date_map = get_date_weekday_map(
#             s.start_date.strftime("%Y-%m-%d"),
#             s.end_date.strftime("%Y-%m-%d")
#         )
#         all_dates.update(date_map.items())

#     date_weekday_map = {d: wd for d, wd in all_dates}
#     study_calendar = {d: getattr(user, f"study_time_{wd}") for d, wd in all_dates}

#     return {
#         "users": [user_data],
#         "subjects": subject_list,
#         "plans": plan_list,
#         "date_weekday_map": date_weekday_map,
#         "study_calendar": study_calendar
#     }

# # GPT 결과 반영
# def apply_plan_dates(db, plan_dates):
#     updated = 0
#     for plan in plan_dates:
#         plan_id = plan.get("plan_id")
#         plan_date = plan.get("plan_date")
#         if plan_id and plan_date:
#             db_plan = db.query(Plan).filter(Plan.plan_id == plan_id).first()
#             if db_plan and db_plan.plan_date != plan_date:
#                 db_plan.plan_date = plan_date
#                 updated += 1
#     db.commit()
#     return updated

# # FastAPI에서 호출할 수 있도록 하는 진입점 함수
# def run_schedule_for_user(user_id: int, db):
#     try:
#         user, subjects, plans = fetch_user_data(db, user_id)

#         if not user:
#             return {"error": "해당 유저가 존재하지 않습니다."}
#         elif not plans:
#             return {"message": "배정할 계획이 없습니다."}

#         reset_old_plan_dates(db, user_id)
#         prompt_data = build_prompt_data(user, subjects, plans)
#         plan_dates = get_plan_schedule_from_gpt(prompt_data)

#         if plan_dates:
#             if "error" in plan_dates[0]:
#                 return {"warning": plan_dates[0]["error"]}
#             updated_count = apply_plan_dates(db, plan_dates)
#             return {"message": f"\u2705 계획 {updated_count}건 날짜 배정 완료!"}
#         else:
#             return {"warning": "계획 날짜 배정 결과가 비어 있습니다."}

#     except Exception as e:
#         return {"error": str(e)}