import os
from dotenv import load_dotenv
from openai import OpenAI

# .env 파일 로드
load_dotenv()

# 환경 변수에서 API 키 가져오기
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# API 키 검증
if not OPENAI_API_KEY:
    raise ValueError("API 키 로드 실패! .env 파일을 확인하세요.")

# 최신 방식 OpenAI 클라이언트 사용
client = OpenAI(api_key=OPENAI_API_KEY)

# GPT 호출 함수 (v1.0+ 방식)
def ask_gpt(prompt, model="gpt-3.5-turbo", max_tokens=3000, temperature=0.7):
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens,
            temperature=temperature
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print("GPT 호출 중 오류 발생:", e)
        input("엔터를 눌러 종료합니다...")
        raise