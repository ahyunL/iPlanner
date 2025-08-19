# backend/services/embedding_service.py
import os, pickle
import numpy as np
from typing import List, Optional
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
VECTOR_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "vector_db"))
os.makedirs(VECTOR_DIR, exist_ok=True)

# 메타 저장용 pkl (인덱스 경로 + 청크 텍스트 목록)
SAVE_PATH = os.path.join(VECTOR_DIR, "faiss_db.pkl")
# FAISS 인덱스 바이너리 (faiss가 직접 읽고 쓰는 포맷)
INDEX_BIN = os.path.join(VECTOR_DIR, "faiss.index")

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def get_embedding(text: str) -> Optional[List[float]]:
    """OpenAI 임베딩 생성"""
    if not text or not text.strip():
        return None
    try:
        r = client.embeddings.create(model="text-embedding-3-small", input=text)
        return r.data[0].embedding if r.data else None
    except Exception as e:
        print(f"❌ 임베딩 생성 실패: {e}")
        return None

def embed_chunks(chunks: List[str], save_path: str = SAVE_PATH, index_bin: str = INDEX_BIN):
    """
    원문 청크 → 임베딩 → FAISS 인덱스는 .index(바이너리), 메타는 .pkl에 저장
    - faiss는 여기서만(필요할 때만) 임포트해 OpenMP 충돌을 줄임
    """
    # ✅ 지연 임포트 (필요할 때만 로드)
    import faiss

    embs: List[List[float]] = []
    for i, c in enumerate(chunks, 1):
        e = get_embedding(c)
        if e is not None:
            embs.append(e)
        else:
            print(f"⚠️ {i}번째 청크 임베딩 실패, 스킵")

    if not embs:
        print("❌ 저장할 임베딩이 없습니다. 생성 중단")
        return []

    arr = np.array(embs, dtype="float32")
    index = faiss.IndexFlatL2(arr.shape[1])
    index.add(arr)

    # ✅ 인덱스는 faiss 전용 바이너리로 저장(가장 안전)
    faiss.write_index(index, index_bin)

    # ✅ 메타파일엔 인덱스 경로와 청크만 저장
    with open(save_path, "wb") as f:
        pickle.dump({"index_path": os.path.abspath(index_bin), "chunks": chunks}, f)

    print(f"✅ FAISS 인덱스 저장: {os.path.abspath(index_bin)}")
    print(f"✅ 메타(pkl) 저장: {os.path.abspath(save_path)}")
    return embs




