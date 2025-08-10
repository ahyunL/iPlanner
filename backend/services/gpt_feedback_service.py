import openai
import os

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def generate_feedback_prompt(this_week, trend_summary: str) -> str:
    return f"""
당신은 사용자의 학습 멘토입니다. 아래는 이번 주 사용자의 학습 유형 분석 결과와 지난주 대비 변화입니다.

[이번 주 학습 유형]
- 성실도: {this_week.sincerity}
- 반복 유형: {this_week.repetition}
- 공부 시간대: {this_week.timeslot}

[변화된 점]
{trend_summary}

이 정보를 바탕으로 사용자에게 따뜻하고 응원하는 톤으로 2~3문장 정도 피드백을 주세요.
"""

def request_feedback_from_gpt(prompt: str) -> str:
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": (
                    "너는 사용자의 학습 패턴을 분석하고 통찰력 있는 피드백을 제공하는 학습 멘토야. "
                    "단순한 칭찬보다, 사용자의 변화를 해석하고 그에 맞는 조언과 다음 방향성을 제시해줘. "
                    "피드백은 따뜻하지만 멘토다운 신뢰감을 유지해야 해."
                )
            },
            {"role": "user", "content": prompt}
        ],
        temperature=0.7,
    )
    return response.choices[0].message.content

