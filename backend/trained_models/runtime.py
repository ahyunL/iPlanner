# backend/trained_models/runtime.py
from __future__ import annotations
import os, json, pickle, joblib
from pathlib import Path
import numpy as np
import xgboost as xgb

# ====== 경로 ======
BASE_DIR = Path(__file__).resolve().parent
SAVE_DIR = BASE_DIR 

# ====== 로더 ======
def _load_all():
    # scaler
    scaler = joblib.load(SAVE_DIR / "scaler16.joblib")
    # encoders
    with open(SAVE_DIR / "label_encoders.pkl", "rb") as f:
        enc = pickle.load(f)
    # meta (없어도 OK)
    meta = {}
    mp = SAVE_DIR / "meta.json"
    if mp.exists():
        with open(mp, "r") as f:
            meta = json.load(f)

    def _load_head(prefix: str):
        cls = SAVE_DIR / f"{prefix}.joblib"
        bst = SAVE_DIR / f"{prefix}.booster"
        if cls.exists():
            return joblib.load(cls)
        if bst.exists():
            b = xgb.Booster()
            b.load_model(str(bst))
            return b
        raise FileNotFoundError(f"{prefix} 모델 파일이 없습니다.")
    clf_s = _load_head("xgb_sincerity")
    clf_r = _load_head("xgb_repetition")
    clf_t = _load_head("xgb_timeslot")

    return clf_s, clf_r, clf_t, scaler, enc, meta

# 싱글톤 캐시
_CACHE = None
def _get():
    global _CACHE
    if _CACHE is None:
        _CACHE = _load_all()
    return _CACHE  # (clf_s, clf_r, clf_t, scaler, enc, meta)

# ====== 전처리: 7x7 → 7x16 → (1,112) ======
def _to_16_features(week_7x7: np.ndarray) -> np.ndarray:
    arr = np.array(week_7x7, dtype=np.float32).reshape(7, 7)
    diff  = np.diff(arr, axis=0, prepend=arr[:1, :])      # (7,7)
    arr14 = np.concatenate([arr, diff], axis=1)           # (7,14)
    dow = np.arange(7)
    sincos = np.stack([np.sin(2*np.pi*dow/7), np.cos(2*np.pi*dow/7)], axis=1)  # (7,2)
    arr16 = np.concatenate([arr14, sincos], axis=1)       # (7,16)
    return arr16

def _predict_head(model, flat_112: np.ndarray, n_classes: int, ntree_limit: int | None):
    if isinstance(model, xgb.Booster):
        dtest = xgb.DMatrix(flat_112)
        if ntree_limit and ntree_limit > 0:
            prob = model.predict(dtest, iteration_range=(0, ntree_limit))
        else:
            prob = model.predict(dtest)
        return int(np.argmax(prob.reshape(-1, n_classes), axis=1)[0])
    else:
        prob = model.predict_proba(flat_112)
        return int(np.argmax(prob.reshape(-1, n_classes), axis=1)[0])

# ====== 외부에서 쓰는 API들 ======
def predict_user_type_xgb(sample_7x7: list[list[float]]) -> dict:
    """
    입력: 7일×7특징(총/오전/오후/저녁/심야/반복/달성률)
    출력: {"성실도":..., "반복형":..., "시간대":...}
    """
    clf_s, clf_r, clf_t, scaler, enc, meta = _get()
    le_s, le_r, le_t = enc["sincerity"], enc["repetition"], enc["timeslot"]
    ntree = (meta.get("ntree_limit", {}) if isinstance(meta, dict) else {})
    arr16 = _to_16_features(sample_7x7)
    flat = scaler.transform(arr16.reshape(-1, arr16.shape[1])).reshape(1, -1)
    sid = _predict_head(clf_s, flat, len(le_s.classes_), ntree.get("sincerity"))
    rid = _predict_head(clf_r, flat, len(le_r.classes_), ntree.get("repetition"))
    tid = _predict_head(clf_t, flat, len(le_t.classes_), ntree.get("timeslot"))
    return {
        "성실도": le_s.inverse_transform([sid])[0],
        "반복형": le_r.inverse_transform([rid])[0],
        "시간대": le_t.inverse_transform([tid])[0],
    }

def summarize_week(mat7x7: list[list[float]]) -> dict:
    # 기존 요약 로직 간단 버전(원하면 더 자세히 확장 가능)
    totals = [sum(r) for r in mat7x7]
    missing = sum(1 for t in totals if t <= 0)
    weekend = sum(mat7x7[i][0] for i in (5,6)) / (sum(sum(r) for r in mat7x7) + 1e-6)
    return {
        "missing_days": missing,
        "raw_pattern": totals,          # 하루 총학습시간(분)
        "weekend_share": round(weekend, 3),
    }
