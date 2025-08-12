# services/embedding_service.py (수정)

import os
import numpy as np
import pickle
from openai import OpenAI
from dotenv import load_dotenv
from typing import List, Optional
import faiss

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SAVE_PATH = os.path.abspath(os.path.join(BASE_DIR, "..", "vector_db", "faiss_db.pkl"))

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def get_embedding(text: str) -> Optional[List[float]]:
    if not text or not text.strip():
        return None
    try:
        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=text
        )
        return response.data[0].embedding if response.data else None
    except Exception as e:
        print(f"❌ 임베딩 생성 실패: {e}")
        return None
def embed_chunks(chunks: List[str], save_path: str = SAVE_PATH):
    embeddings = []
    for i, chunk in enumerate(chunks, start=1):
        emb = get_embedding(chunk)
        if emb is not None:
            embeddings.append(emb)
        else:
            print(f"⚠️ {i}번째 청크 임베딩 실패, 건너뜀")

    if not embeddings:
        print("❌ 저장할 임베딩이 없습니다. FAISS 파일을 생성하지 않습니다.")
        return []

    embeddings = np.array(embeddings, dtype="float32")
    dim = embeddings.shape[1]
    index = faiss.IndexFlatL2(dim)
    index.add(embeddings)

    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    with open(save_path, "wb") as f:
        pickle.dump(index, f)

    print(f"✅ FAISS 인덱스 저장 완료: {os.path.abspath(save_path)}")
    return embeddings.tolist()  # ✅ 여기서 반환
