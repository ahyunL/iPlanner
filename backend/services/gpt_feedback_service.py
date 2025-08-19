# services/gpt_feedback_service.py
import os
from datetime import date, timedelta
from typing import Any, Dict, List, Union

import openai

# OpenAI 클라이언트 (환경변수에서 키 주입)
client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# ─────────────────────────────────────────────────────────────
# 내부 유틸
# ─────────────────────────────────────────────────────────────
def _get(attr_or_key: Union[Dict[str, Any], Any], name: str, default: Any = "") -> Any:
    """dict와 객체 속성 접근을 동시에 지원"""
    if isinstance(attr_or_key, dict):
        return attr_or_key.get(name, default)
    return getattr(attr_or_key, name, default)

DAYS_KR = ["월", "화", "수", "목", "금", "토", "일"]

def _format_week_pattern_verbose(raw_pattern: List[int]) -> str:
    """
    요일 리듬을 GPT가 바로 읽을 수 있도록 월~일 라벨과 함께 출력.
    예: 월=60, 화=90, 수=33, ...
    + 총합/증감 요약 포함
    """
    if not raw_pattern or len(raw_pattern) != 7:
        return "데이터 부족"
    detail = ", ".join(f"{DAYS_KR[i]}={int(raw_pattern[i])}" for i in range(7))
    total = int(sum(raw_pattern))
    diffs = [raw_pattern[i] - raw_pattern[i - 1] for i in range(1, 7)]
    up = sum(1 for d in diffs if d > 0)
    down = sum(1 for d in diffs if d < 0)
    flat = sum(1 for d in diffs if d == 0)
    return f"일자별 학습량: {detail} (총합 {total}분, 증감: ↑{up}일 / ↓{down}일 / →{flat}일)"

def _timeslot_hint(timeslot: str) -> str:
    """모델이 판단한 집중 시간대를 활용한 코칭 힌트 한 줄(프롬프트용)"""
    mapping = {
        "오전": "오전 집중도가 높으니 가장 어려운 과목과 암기/문제풀이를 오전 첫 슬롯에 배치",
        "오후": "오후에 에너지가 오르니 심화 학습은 오후, 반복/정리는 오전·저녁으로 쪼개기",
        "저녁": "저녁 몰입이 좋으니 핵심 과목을 저녁 고정, 오전엔 가벼운 예열/리뷰",
        "심야": "심야 집중형이므로 과도한 각성은 피하고 40–50분 몰입+짧은 휴식 리듬 유지",
    }
    return mapping.get(timeslot or "", "집중이 잘 되는 시간대를 고정 슬롯으로 확보해 핵심 과목을 먼저 배치")

def _peak_trough_summary(raw_pattern: List[int]) -> str:
    """주간 피크/저점을 간단 요약 (동률 있으면 상위 1개씩만 표기)"""
    if not raw_pattern or len(raw_pattern) != 7:
        return ""
    vals = list(map(int, raw_pattern))
    max_i = int(max(range(7), key=lambda i: vals[i]))
    min_i = int(min(range(7), key=lambda i: vals[i]))
    return f"피크: {DAYS_KR[max_i]}({vals[max_i]}분) / 저점: {DAYS_KR[min_i]}({vals[min_i]}분)"

def _early_late_bias(raw_pattern: List[int]) -> str:
    """전반부(월~목) vs 후반부(금~일) 편향 요약"""
    if not raw_pattern or len(raw_pattern) != 7:
        return ""
    front = sum(raw_pattern[:4]) / 4.0
    back = sum(raw_pattern[4:]) / 3.0
    if abs(front - back) < 1e-6:
        return "전반부·후반부 편차 없음"
    return "전반부(월~목) 강세" if front > back else "후반부(금~일) 강세"

def _build_rhythm_summary(raw_pattern: List[int]) -> str:
    """GPT가 바로 활용할 수 있는 주간 리듬 요약 문장 묶음"""
    if not raw_pattern or len(raw_pattern) != 7:
        return "주간 리듬 분석 불가(데이터 부족)"
    lines = [
        _format_week_pattern_verbose(raw_pattern),
        _peak_trough_summary(raw_pattern),
        _early_late_bias(raw_pattern),
    ]
    return "\n".join([ln for ln in lines if ln])

def _infer_week_progress(week_start_str: str):
    """
    이번 주 프롬프트인지 판별하고, 오늘 요일과 남은 '자연 결측' 일수를 계산.
    + 남은 요일(한글) 리스트 제공 → 주중 계획형 피드백에 활용
    """
    try:
        ws = date.fromisoformat(week_start_str)
    except Exception:
        return {"is_current_week": False}

    today = date.today()
    this_monday = today - timedelta(days=today.weekday())
    if ws != this_monday:
        return {"is_current_week": False}

    today_idx = (today - ws).days  # 0=월 ... 6=일
    remain = max(0, 6 - today_idx)
    upcoming_days_kr = [DAYS_KR[i] for i in range(today_idx + 1, 7)]  # 예: 수/목/금/토/일
    return {
        "is_current_week": True,
        "today_idx": today_idx,
        "today_kr": DAYS_KR[today_idx],
        "remaining_future_days": remain,
        "upcoming_days_kr": upcoming_days_kr,
    }

# ─────────────────────────────────────────────────────────────
# 프롬프트 생성 (추측 금지 + 제공 라벨만 사용)
# ─────────────────────────────────────────────────────────────
def generate_feedback_prompt(this_week: Union[Dict[str, Any], Any], trend_summary: str) -> str:
    """
    this_week 예시:
      - prediction: {"성실도","반복형","시간대"} (선호)
      - sincerity/repetition/timeslot 직접 키로 넘어올 수도 있음 (후방호환)
      - 선택: week_start_date(str), missing_days(int), raw_pattern(List[int]),
             day_labels(List[str: "YYYY-MM-DD(월)"]), top_day/low_day({"label","minutes"})
    """
    pred = _get(this_week, "prediction", {})
    sincerity = _get(this_week, "sincerity", _get(pred, "성실도", "?"))
    repetition = _get(this_week, "repetition", _get(pred, "반복형", "?"))
    timeslot = _get(this_week, "timeslot", _get(pred, "시간대", "?"))
    week_start = _get(this_week, "week_start_date", "")
    missing_days = _get(this_week, "missing_days", None)
    raw_pattern = _get(this_week, "raw_pattern", None)

    # 라벨·피크/저점
    day_labels: List[str] = _get(this_week, "day_labels", [])
    top_day = _get(this_week, "top_day", {})
    low_day = _get(this_week, "low_day", {})

    rhythm_block = _build_rhythm_summary(raw_pattern) if isinstance(raw_pattern, list) else "주간 리듬 분석 불가"

    # 요일-날짜 매핑 라인
    mapping_line = ""
    if isinstance(day_labels, list) and len(day_labels) == 7:
        mapping_line = "- 요일-날짜 매핑: " + ", ".join(
            f"{DAYS_KR[i]}={day_labels[i]}" for i in range(7)
        ) + "\n"

    # 피크/저점 라인
    peak_trough_line = ""
    if isinstance(top_day, dict) and isinstance(low_day, dict) and top_day.get("label") and low_day.get("label"):
        peak_trough_line = (
            f"- 최고치: {top_day.get('label')} {top_day.get('minutes')}분 / "
            f"최저치: {low_day.get('label')} {low_day.get('minutes')}분\n"
        )

    # 결측 라인(0이면 숨김)
    missing_line = (
        f"- 빈 날: {missing_days}일\n"
        if isinstance(missing_days, int) and missing_days > 0 else ""
    )

    # 진행 상황(현재 주간이면 오늘 이후 0은 '자연 결측')
    progress = _infer_week_progress(week_start)
    progress_line = ""
    if progress.get("is_current_week") and progress.get("remaining_future_days", 0) > 0:
        progress_line = (
            f"- 진행 상황: 오늘은 {progress['today_kr']}요일이며, "
            f"남은 {progress['remaining_future_days']}일은 아직 진행 전(자연 결측)입니다.\n"
        )

    # 모드 결정: 일요일(완주) vs 결측/주중(계획)
    remaining = progress.get("remaining_future_days", 0)
    is_full_week = (
        # 현재 주간이며 남은 요일 0 → 일요일까지 완료, 또는 과거 주간
        (progress.get("is_current_week") and remaining == 0)
        or (not progress.get("is_current_week"))
    )
    mode = "FULL" if is_full_week and (not isinstance(missing_days, int) or missing_days == 0) else "MIDWEEK"

    # 남은 요일 안내(계획형에서만)
    upcoming = progress.get("upcoming_days_kr", [])
    upcoming_line = (
        "- 남은 요일: " + ", ".join(upcoming) + "\n"
        if mode == "MIDWEEK" and upcoming else ""
    )

    slot_hint = _timeslot_hint(timeslot)

    # 공통 헤더
    header = f"""
당신은 사용자의 학습 멘토입니다. 아래는 이번 주 학습 유형 분석과 지난주 대비 변화입니다.
모델은 주간 리듬과 일일 변화를 반영한 분류 결과를 제공합니다.

[이번 주 학습 유형]
- 기간 시작: {week_start}
- 성실도: {sincerity}
- 반복 유형(모델): {repetition}
- 집중 시간대(모델): {timeslot}
{mapping_line}{peak_trough_line}{missing_line}{progress_line}{upcoming_line}- 주간 리듬 요약:
{rhythm_block}

[변화된 점]
{trend_summary}
""".strip()

    # 모드별 지침
    if mode == "FULL":
        guidelines = f"""
[작성 지침 — 반드시 따르세요]
1) 따뜻하고 응원하는 톤으로 **정확히 2~3문장**으로 작성하세요.
2) **제공된 요일/날짜만** 사용하고 임의 추측을 금지합니다.
3) 이번 주 결과를 간단히 요약하고, **다음 주를 위한 1가지 실행 제안**을 포함하세요.
4) **집중 시간대({timeslot})** 특성을 활용한 코칭을 **1개 이상** 포함하세요.
5) 반복 유형({repetition})에 맞춘 **즉시 실행 행동 1가지**를 제시하세요.
""".strip()
    else:
        guidelines = f"""
[작성 지침 — 반드시 따르세요]
1) 따뜻하고 응원하는 톤으로 **정확히 2~3문장**으로 작성하세요.
2) **현재 주간의 0값은 자연 결측**으로 간주하고 하락 평가를 하지 마세요.
3) 남은 요일({", ".join(upcoming) if upcoming else "이번 주 남은 기간"})에 대해
   **집중 시간대({timeslot})**를 활용한 **구체적 실행 팁 1가지**를 제시하세요.
4) 반복 유형({repetition})에 맞춰 **짧은 목표(예: 15–20분 세션, 미니 체크리스트)**를 권장하세요.
5) **제공된 요일/날짜만** 사용하고 임의 추측을 금지합니다.
""".strip()

    return f"{header}\n\n{guidelines}"

# ─────────────────────────────────────────────────────────────
# GPT 호출
# ─────────────────────────────────────────────────────────────
def request_feedback_from_gpt(prompt: str) -> str:
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": (
                    "너는 사용자의 학습 패턴을 분석하고 통찰력 있는 피드백을 제공하는 멘토야. "
                    "단순한 칭찬이 아니라, 사용자의 리듬(요일/시간대)과 반복 유형을 기반으로 "
                    "구체적이고 실행 가능한 한두 가지 행동을 제시해."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        temperature=0.7,
        max_tokens=220,
    )
    return response.choices[0].message.content


# # services/gpt_feedback_service.py
# import os
# from datetime import date, timedelta
# from typing import Any, Dict, List, Union

# import openai

# # OpenAI 클라이언트 (환경변수에서 키 주입)
# client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# # ─────────────────────────────────────────────────────────────
# # 내부 유틸
# # ─────────────────────────────────────────────────────────────
# def _get(attr_or_key: Union[Dict[str, Any], Any], name: str, default: Any = "") -> Any:
#     """dict와 객체 속성 접근을 동시에 지원"""
#     if isinstance(attr_or_key, dict):
#         return attr_or_key.get(name, default)
#     return getattr(attr_or_key, name, default)

# DAYS_KR = ["월", "화", "수", "목", "금", "토", "일"]

# def _format_week_pattern_verbose(raw_pattern: List[int]) -> str:
#     """
#     요일 주기성을 GPT가 바로 읽을 수 있도록 월~일 라벨과 함께 출력.
#     예: 월=60, 화=90, 수=33, ...
#     + 총합/증감 요약 포함
#     """
#     if not raw_pattern or len(raw_pattern) != 7:
#         return "데이터 부족"
#     detail = ", ".join(f"{DAYS_KR[i]}={int(raw_pattern[i])}" for i in range(7))
#     total = int(sum(raw_pattern))
#     diffs = [raw_pattern[i] - raw_pattern[i - 1] for i in range(1, 7)]
#     up = sum(1 for d in diffs if d > 0)
#     down = sum(1 for d in diffs if d < 0)
#     flat = sum(1 for d in diffs if d == 0)
#     return f"일자별 학습량: {detail} (총합 {total}분, 증감: ↑{up}일 / ↓{down}일 / →{flat}일)"

# def _timeslot_hint(timeslot: str) -> str:
#     """모델이 판단한 집중 시간대를 활용한 코칭 힌트 한 줄(프롬프트용)"""
#     mapping = {
#         "오전": "오전 집중도가 높으니 가장 어려운 과목과 암기/문제풀이를 오전 첫 슬롯에 배치",
#         "오후": "오후에 에너지가 오르니 심화 학습은 오후, 반복/정리는 오전·저녁으로 쪼개기",
#         "저녁": "저녁 몰입이 좋으니 핵심 과목을 저녁 고정, 오전엔 가벼운 예열/리뷰",
#         "심야": "심야 집중형이므로 과도한 각성은 피하고 40–50분 몰입+짧은 휴식 리듬 유지",
#     }
#     return mapping.get(timeslot or "", "집중이 잘 되는 시간대를 고정 슬롯으로 확보해 핵심 과목을 먼저 배치")

# def _peak_trough_summary(raw_pattern: List[int]) -> str:
#     """주간 피크/저점을 간단 요약 (동률 있으면 상위 1개씩만 표기)"""
#     if not raw_pattern or len(raw_pattern) != 7:
#         return ""
#     vals = list(map(int, raw_pattern))
#     max_i = int(max(range(7), key=lambda i: vals[i]))
#     min_i = int(min(range(7), key=lambda i: vals[i]))
#     return f"피크: {DAYS_KR[max_i]}({vals[max_i]}분) / 저점: {DAYS_KR[min_i]}({vals[min_i]}분)"

# def _early_late_bias(raw_pattern: List[int]) -> str:
#     """전반부(월~목) vs 후반부(금~일) 편향 요약"""
#     if not raw_pattern or len(raw_pattern) != 7:
#         return ""
#     front = sum(raw_pattern[:4]) / 4.0
#     back = sum(raw_pattern[4:]) / 3.0
#     if abs(front - back) < 1e-6:
#         return "전반부·후반부 편차 없음"
#     return "전반부(월~목) 강세" if front > back else "후반부(금~일) 강세"

# def _build_rhythm_summary(raw_pattern: List[int]) -> str:
#     """GPT가 바로 활용할 수 있는 주기성 요약 문장 묶음"""
#     if not raw_pattern or len(raw_pattern) != 7:
#         return "주간 리듬 분석 불가(데이터 부족)"
#     lines = [
#         _format_week_pattern_verbose(raw_pattern),
#         _peak_trough_summary(raw_pattern),
#         _early_late_bias(raw_pattern),
#     ]
#     return "\n".join([ln for ln in lines if ln])

# def _infer_week_progress(week_start_str: str):
#     """
#     이번 주 프롬프트인지 판별하고, 오늘 요일과 남은 '자연 결측' 일수를 계산.
#     """
#     try:
#         ws = date.fromisoformat(week_start_str)
#     except Exception:
#         return {"is_current_week": False}

#     today = date.today()
#     this_monday = today - timedelta(days=today.weekday())
#     if ws != this_monday:
#         return {"is_current_week": False}

#     today_idx = (today - ws).days  # 0=월 ... 6=일
#     remain = max(0, 6 - today_idx)
#     return {
#         "is_current_week": True,
#         "today_idx": today_idx,
#         "today_kr": DAYS_KR[today_idx],
#         "remaining_future_days": remain,
#     }

# # ─────────────────────────────────────────────────────────────
# # 프롬프트 생성 (추측 금지 + 제공 라벨만 사용)
# # ─────────────────────────────────────────────────────────────
# def generate_feedback_prompt(this_week: Union[Dict[str, Any], Any], trend_summary: str) -> str:
#     """
#     this_week 예시:
#       - prediction: {"성실도","반복형","시간대"} (선호)
#       - sincerity/repetition/timeslot 직접 키로 넘어올 수도 있음 (후방호환)
#       - 선택: week_start_date(str), missing_days(int), raw_pattern(List[int]),
#              day_labels(List[str: "YYYY-MM-DD(월)"]), top_day/low_day({"label","minutes"})
#     """
#     pred = _get(this_week, "prediction", {})
#     sincerity = _get(this_week, "sincerity", _get(pred, "성실도", "?"))
#     repetition = _get(this_week, "repetition", _get(pred, "반복형", "?"))
#     timeslot = _get(this_week, "timeslot", _get(pred, "시간대", "?"))
#     week_start = _get(this_week, "week_start_date", "")
#     missing_days = _get(this_week, "missing_days", None)
#     raw_pattern = _get(this_week, "raw_pattern", None)

#     # 라벨·피크/저점
#     day_labels: List[str] = _get(this_week, "day_labels", [])
#     top_day = _get(this_week, "top_day", {})
#     low_day = _get(this_week, "low_day", {})

#     rhythm_block = _build_rhythm_summary(raw_pattern) if isinstance(raw_pattern, list) else "주간 리듬 분석 불가"

#     # 요일-날짜 매핑 라인
#     mapping_line = ""
#     if isinstance(day_labels, list) and len(day_labels) == 7:
#         mapping_line = "- 요일-날짜 매핑: " + ", ".join(
#             f"{DAYS_KR[i]}={day_labels[i]}" for i in range(7)
#         ) + "\n"

#     # 피크/저점 라인
#     peak_trough_line = ""
#     if isinstance(top_day, dict) and isinstance(low_day, dict) and top_day.get("label") and low_day.get("label"):
#         peak_trough_line = (
#             f"- 최고치: {top_day.get('label')} {top_day.get('minutes')}분 / "
#             f"최저치: {low_day.get('label')} {low_day.get('minutes')}분\n"
#         )

#     # 결측 라인
#     missing_line = f"- 빈 날: {missing_days}일\n" if isinstance(missing_days, int) else ""

#     # 진행 상황(현재 주간이면 오늘 이후 0은 '자연 결측')
#     progress = _infer_week_progress(week_start)
#     progress_line = ""
#     if progress.get("is_current_week"):
#         progress_line = (
#             f"- 진행 상황: 오늘은 {progress['today_kr']}요일이며, "
#             f"남은 {progress['remaining_future_days']}일은 아직 진행 전(자연 결측)입니다.\n"
#         )

#     slot_hint = _timeslot_hint(timeslot)

#     return f"""
# 당신은 사용자의 학습 멘토입니다. 아래는 이번 주 학습 유형 분석과 지난주 대비 변화입니다.
# 모델은 요일 주기(sin/cos)와 일일 변화(Δ)를 반영한 분류 결과를 제공합니다.

# [이번 주 학습 유형]
# - 기간 시작: {week_start}
# - 성실도: {sincerity}
# - 반복 유형(모델): {repetition}
# - 집중 시간대(모델): {timeslot}
# {mapping_line}{peak_trough_line}{missing_line}{progress_line}- 주간 리듬 요약:
# {rhythm_block}

# [변화된 점]
# {trend_summary}

# [작성 지침 — 반드시 따르세요]
# 1) 따뜻하고 응원하는 톤으로 **정확히 2~3문장**으로 작성하세요.
# 2) **요일/날짜는 반드시 위에 제공된 라벨만 사용**하고, 임의 추측을 금지합니다.
# 3) **현재 주간인 경우** 오늘 이후 0값은 **자연 결측**으로 간주하고, 하락 평가를 하지 마세요.
# 4) **요일 이름을 최소 1회 이상** 직접 언급하며 주간 리듬을 해석하세요.
# 5) **집중 시간대({timeslot})** 특성을 활용한 코칭을 **1개 이상** 포함하세요.
# 6) 반복 유형({repetition})에 맞춰 **즉시 실행 가능한 행동 1가지**를 제시하세요.
# """.strip()

# # ─────────────────────────────────────────────────────────────
# # GPT 호출
# # ─────────────────────────────────────────────────────────────
# def request_feedback_from_gpt(prompt: str) -> str:
#     response = client.chat.completions.create(
#         model="gpt-4o",
#         messages=[
#             {
#                 "role": "system",
#                 "content": (
#                     "너는 사용자의 학습 패턴을 분석하고 통찰력 있는 피드백을 제공하는 멘토야. "
#                     "단순한 칭찬이 아니라, 사용자의 리듬(요일/시간대)과 반복 유형을 기반으로 "
#                     "구체적이고 실행 가능한 한두 가지 행동을 제시해."
#                 ),
#             },
#             {"role": "user", "content": prompt},
#         ],
#         temperature=0.7,
#         max_tokens=220,
#     )
#     return response.choices[0].message.content



