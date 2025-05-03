# # FastAPI 서버 테스트시 사용하는 명령어: uvicorn main:app --reload

# # backend/services/ai_planner.py
# # row_plan 저장 → GPT로 계획 분해 → plan 저장 → 리스트 반환


import json
import ast
import pymysql
from config import ask_gpt
from schemas.plan_schema import ToDoItem

# ✅ GPT 응답을 안전하게 파싱
def safe_parse_gpt_response(response: str) -> list:
    content = response.strip()
    print("📤 GPT 응답 원문 >>>", repr(content))

    if content.startswith("- "):
        return [line[2:].strip() for line in content.split("\n") if line.startswith("- ")]

    if not content.startswith("[") or not content.endswith("]"):
        print("⚠️ GPT 응답이 리스트 형식이 아님 → 무시됨")
        return []

    try:
        return ast.literal_eval(content)
    except Exception as e:
        print(f"❌ 리스트 파싱 실패: {e}")
        return []

# ✅ 유니코드 정리 (이모지 깨짐 방지)
def clean_unicode(text: str) -> str:
    return text.encode("utf-8", "replace").decode("utf-8")

# ✅ GPT로 학습 항목 분해
def expand_row_plan_name(row_plan_name: str) -> list:
    system_prompt = (
        "너는 학습 계획을 실제 콘텐츠 단위로만 나눠주는 도우미야.\n\n"
        "💡 반드시 다음 조건을 지켜:\n"
        "1. 출력은 반드시 파이썬 리스트 형식으로 해. 예: ['1강', '2강', '3강'] 또는 ['챕터 1', '챕터 2']\n"
        "2. 출력 외에 아무 말도 하지 마 (예시, 설명, 마크다운, 말머리 절대 금지)\n"
        "3. 아래 단어가 들어간 항목은 절대 포함하지 마:\n"
        "   복습, 정리, 요약, 계획, 느낀점, 실습, 문제풀이, 이해, 확인, 메모, 정리하기, 작성하기, 질문 등\n"
        "4. 반드시 실제 강의나 교재의 콘텐츠 단위로만 나눠. (예: 1강, 2강, 1주차, 챕터 1, 챕터 2)\n\n"
        "✅ 출력 예시:\n['1강', '2강', '3강']\n['1주차', '2주차']\n['챕터 1', '챕터 2', '챕터 3']\n\n"
        "다른 말 하지 말고 리스트 하나만 출력해."
    )

    user_prompt = f"\n\n입력 문장: {row_plan_name}\n리스트로 나눠줘."

    try:
        full_prompt = clean_unicode(system_prompt + user_prompt)
        response = ask_gpt(prompt=full_prompt, model="gpt-3.5-turbo", temperature=0.2)
        return safe_parse_gpt_response(response)
    except Exception as e:
        print(f"❌ GPT 호출 실패: {e}")
        return []

# ✅ row_plan 테이블 저장
def save_row_plans_to_db(user_data: dict):
    db = pymysql.connect(
        host='localhost',
        user='root',
        password='1204',
        database='yuminsu',
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )
    try:
        with db.cursor() as cursor:
            for plan in user_data["row_plans"]:
                cursor.execute("""
                    INSERT INTO row_plan (user_id, subject_id, row_plan_name, type, repetition, ranking)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    user_data["user_id"],
                    user_data["subject_id"],
                    plan["row_plan_name"],
                    plan["type"],
                    plan["repetition"],
                    plan["ranking"]
                ))
        db.commit()
        print("✅ row_plan 테이블 저장 완료!")
    except Exception as e:
        print("❌ row_plan 저장 오류:", e)
    finally:
        db.close()

# ✅ 계획(plan) 생성 및 저장
def generate_and_save_plans(user_id: int, subject_id: int):
    db = pymysql.connect(
        host='localhost',
        user='root',
        password='1204',
        database='yuminsu',
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )
    try:
        with db.cursor() as cursor:
            cursor.execute("""
                SELECT * FROM row_plan
                WHERE user_id = %s AND subject_id = %s
                ORDER BY ranking ASC
            """, (user_id, subject_id))
            row_plans = cursor.fetchall()

        todo_items = []
        for plan in row_plans:
            tasks = expand_row_plan_name(plan["row_plan_name"])
            for r in range(1, plan["repetition"] + 1):
                for t in tasks:
                    todo_items.append({
                        "user_id": user_id,
                        "subject_id": subject_id,
                        "plan_name": f"{plan['row_plan_name']} - {r}회차 {t}",
                        "complete": False,
                        "plan_time": 60,  # 기본 학습 시간
                        "plan_date": None  # 날짜 배정 전
                    })

        with db.cursor() as cursor:
            for item in todo_items:
                cursor.execute("""
                    INSERT INTO plan (user_id, subject_id, plan_name, complete, plan_time, plan_date)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    item["user_id"],
                    item["subject_id"],
                    item["plan_name"],
                    item["complete"],
                    item["plan_time"],
                    item["plan_date"]
                ))

        db.commit()
        print(f"✅ plan {len(todo_items)}개 저장 완료!")

    except Exception as e:
        print("❌ 계획 생성 또는 저장 오류:", e)
    finally:
        db.close()

# ✅ plan 테이블에서 ToDoItem 리스트 반환
def create_plan_list_for_response(user_id: int, subject_id: int):
    db = pymysql.connect(
        host='localhost',
        user='root',
        password='1204',
        database='yuminsu',
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )
    try:
        with db.cursor() as cursor:
            cursor.execute("""
                SELECT plan_id, plan_name, plan_time, plan_date, complete
                FROM plan
                WHERE user_id = %s AND subject_id = %s
                ORDER BY plan_id
            """, (user_id, subject_id))

            rows = cursor.fetchall()
            return [ToDoItem(**row) for row in rows]

    except Exception as e:
        print("❌ plan 리스트 응답 오류:", e)
        return []
    finally:
        db.close()

