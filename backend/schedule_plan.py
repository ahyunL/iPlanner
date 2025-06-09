import os
import json
import pymysql
from datetime import datetime, timedelta, date
from collections import defaultdict
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# GPT 클라이언트 설정
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# DB 연결
db = pymysql.connect(
    host='localhost',
    user='root',
    password='1204',
    database='yuminsu',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

# GPT 호출 함수
def get_plan_schedule_from_gpt(data: dict) -> list:
    system_prompt = (
        "당신은 학습 계획을 날짜별로 배정해주는 스케줄링 도우미입니다.\n"
        "(생략) [중략된 프롬프트 내용은 그대로 유지]\n"
        "예시: [{\"plan_id\": 1, \"plan_date\": \"2025-04-01\"}, {\"plan_id\": 2, \"plan_date\": \"2025-04-02\"}, ...]"
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
    try:
        return json.loads(result)
    except Exception as e:
        print("GPT 응답 파싱 실패:", result)
        return []

# 재생성할 유저 ID (임시 고정)
TARGET_USER_ID = 3

def fetch_user_data(cursor, user_id):
    cursor.execute("SELECT * FROM user WHERE user_id = %s", (user_id,))
    user = cursor.fetchone()
    if not user:
        return None, [], []

    cursor.execute("SELECT * FROM subject WHERE user_id = %s", (user_id,))
    subjects = cursor.fetchall()

    cursor.execute("""
        SELECT DISTINCT plan_name FROM plan 
        WHERE complete = TRUE AND user_id = %s;
    """, (user_id,))
    completed_names = {row["plan_name"] for row in cursor.fetchall()}

    cursor.execute("""
        SELECT plan_id, user_id, subject_id, plan_time, plan_name, plan_date
        FROM plan
        WHERE complete = FALSE AND user_id = %s;
    """, (user_id,))
    all_plans = cursor.fetchall()
    filtered_plans = [p for p in all_plans if p["plan_name"] not in completed_names]

    return user, subjects, filtered_plans

def reset_old_plan_dates(cursor, user_id):
    today = date.today().strftime("%Y-%m-%d")
    cursor.execute("""
        UPDATE plan
        SET plan_date = NULL
        WHERE complete = FALSE AND plan_date < %s AND user_id = %s;
    """, (today, user_id))

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

def build_prompt_data(user, subjects, plans):
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    user_data = {
        "user_id": user["user_id"],
        "study_time": {d: user[f"study_time_{d}"] for d in days}
    }

    subject_list = []
    plan_list = [{
        "plan_id": p["plan_id"],
        "user_id": p["user_id"],
        "subject_id": p["subject_id"],
        "plan_time": p["plan_time"],
        "plan_name": p["plan_name"]
    } for p in plans]

    all_dates = set()
    for s in subjects:
        subject_list.append({
            "subject_id": s["subject_id"],
            "user_id": s["user_id"],
            "start_date": s["start_date"].strftime("%Y-%m-%d"),
            "end_date": s["end_date"].strftime("%Y-%m-%d")
        })
        date_map = get_date_weekday_map(
            s["start_date"].strftime("%Y-%m-%d"),
            s["end_date"].strftime("%Y-%m-%d")
        )
        all_dates.update(date_map.items())

    date_weekday_map = {}
    study_calendar = {}
    for d, wd in all_dates:
        date_weekday_map[d] = wd
        study_calendar[d] = user[f"study_time_{wd}"]

    return {
        "users": [user_data],
        "subjects": subject_list,
        "plans": plan_list,
        "date_weekday_map": date_weekday_map,
        "study_calendar": study_calendar
    }

def apply_plan_dates(cursor, plan_dates):
    updated = 0
    for plan in plan_dates:
        plan_id = plan.get("plan_id")
        plan_date = plan.get("plan_date")
        if plan_id and plan_date:
            cursor.execute("SELECT plan_date FROM plan WHERE plan_id = %s", (plan_id,))
            current = cursor.fetchone()
            if current and current["plan_date"] != plan_date:
                cursor.execute("""
                    UPDATE plan
                    SET plan_date = %s
                    WHERE plan_id = %s;
                """, (plan_date, plan_id))
                updated += 1
    return updated

# 실행
try:
    with db.cursor() as cursor:
        user, subjects, plans = fetch_user_data(cursor, TARGET_USER_ID)

        if not user:
            print("해당 유저 없음.")
        elif not plans:
            print("배정할 계획이 없습니다.")
        else:
            reset_old_plan_dates(cursor, TARGET_USER_ID)
            prompt_data = build_prompt_data(user, subjects, plans)

            # GPT로 날짜 배정
            plan_dates = get_plan_schedule_from_gpt(prompt_data)

            if plan_dates:
                updated_count = apply_plan_dates(cursor, plan_dates)
                db.commit()
                print(f"GPT로 plan_date {updated_count}건 성공적으로 배정 완료!")

except Exception as e:
    print("전체 오류 발생:", e)
finally:
    db.close()