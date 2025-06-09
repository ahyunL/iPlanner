
import os
import json
from datetime import datetime, timedelta, date
from openai import OpenAI
from dotenv import load_dotenv
from db import SessionLocal
from models.user import User
from models.subject import Subject
from models.plan import Plan

load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# GPT 호출 함수
def get_plan_schedule_from_gpt(data: dict) -> list:
    system_prompt = (    "당신은 학습 계획을 날짜별로 배정해주는 스케줄링 도우미입니다.\n"
        "아래 데이터를 기반으로 각 계획(plan)에 적절한 날짜(plan_date)를 배정해주세요.\n\n"
        "💡 조건:\n"
        "- 사용자마다 요일별 공부 가능 시간이 다릅니다.\n"
        "- 각 plan에는 예상 학습 시간(plan_time)이 주어집니다.\n"
        "- 하루에 배정되는 전체 학습 시간은 사용자의 해당 요일 공부 가능 시간을 넘지 않도록 해주세요.\n"
        "- 각 날짜별로 가능한 공부 시간은 study_calendar에 제공됩니다.\n"
        "- 과목(subject)마다 공부 가능한 날짜(start_date ~ end_date)가 주어집니다.\n"
        "- 과목의 시험일(end_date)이 가까울수록 더 높은 우선순위로 배정해주세요.\n"
        "- 같은 계획(plan_name) 내에 '1회독', '2회독' 등 회독 순서가 있는 경우, 순서대로 날짜가 배정되도록 해주세요.\n"
        "- 사용자의 전체 공부 가능 시간 대비 계획이 너무 많아 배정이 불가능한 경우에는 다음과 같이 경고 메시지를 출력해주세요:\n"
        "'공부 시간이 부족하여 모든 계획을 배정할 수 없습니다.'\n"
        "- 같은 날짜에 여러 계획을 배정할 수는 있지만, 반드시 해당 날짜에 이미 배정된 계획들의 plan_time 합계를 누적해서 계산하세요.\n"
        "- 그리고 그 합계가 study_calendar[해당 날짜]를 초과하면 절대 안 됩니다.\n"
        "- 반드시 각 날짜별 누적 학습 시간을 계산하며 배정하세요.\n\n"
        "❗❗❗ 가장 중요한 조건:\n"
        "- 각 계획(plan)은 plan_id가 낮은 순서부터 배정되어야 하며, 순서가 절대로 바뀌어서는 안 됩니다.\n"
        "- 먼저 배정된 날짜의 잔여 시간이 부족하다면, 그 다음 가능한 날짜 중에서 가장 가까운 날짜로 해당 plan을 배정하세요.\n"
        "- 단, 다음 plan이 앞 plan보다 먼저 배정되거나 같은 날에 배정되는 일이 생기면 안 됩니다.\n"
        "- 즉, plan_id 1번이 배정된 날짜보다 앞선 날짜에 plan_id 2번이 배정되면 안 됩니다.\n\n"
        "✅ 결과는 반드시 JSON 배열 형식으로만 반환하세요.\n"
        "예시: [{\"plan_id\": 1, \"plan_date\": \"2025-04-01\"}, {\"plan_id\": 2, \"plan_date\": \"2025-04-02\"}, ...]\n"
        "JSON 객체 안에 'key'를 포함시키지 말고, 반드시 최상위에 배열(list) 형태만 반환하세요."
)

    user_prompt = f"다음 데이터를 참고해서 날짜를 배정해줘:\n{json.dumps(data, ensure_ascii=False)}"

    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        temperature=0.3
    )

    result = response.choices[0].message.content.strip()


    #디버깅용 
    plan_list = data.get("plans", [])
    print("GPT에 전달된 plan_list >>>", json.dumps(plan_list, ensure_ascii=False, indent=2))
    print("GPT 응답 원문 >>>", result)
    try:
        return json.loads(result)
    except Exception as e:
        print("\u274c GPT 응답 파싱 실패:", result)
        return []

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
    today = date.today()
    db.query(Plan).filter(
        Plan.complete == False,
        Plan.plan_date < today,
        Plan.user_id == user_id
    ).update({"plan_date": None})
    db.commit()

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
    study_calendar = {d: getattr(user, f"study_time_{wd}") for d, wd in all_dates}

    return {
        "users": [user_data],
        "subjects": subject_list,
        "plans": plan_list,
        "date_weekday_map": date_weekday_map,
        "study_calendar": study_calendar
    }

# GPT 결과 반영
def apply_plan_dates(db, plan_dates):
    updated = 0
    for plan in plan_dates:
        plan_id = plan.get("plan_id")
        plan_date = plan.get("plan_date")
        if plan_id and plan_date:
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
            updated_count = apply_plan_dates(db, plan_dates)
            return {"message": f"\u2705 GPT로 plan_date {updated_count}건 성공적으로 배정 완료!"}
        else:
            return {"warning": "GPT 응답이 비어 있습니다."}

    except Exception as e:
        return {"error": str(e)}
