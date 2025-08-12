# backend/utils/vector_db_utils.py

import faiss
import numpy as np
import pickle
import os

def save_vector_db(embeddings: list, metadata: list, db_path="backend/vector_db/faiss_db.pkl"):
    try:
        if not embeddings:
            print("❌ save_vector_db: embeddings 리스트가 비어있습니다.")
            return
        if not metadata:
            print("❌ save_vector_db: metadata 리스트가 비어있습니다.")
            return

        dim = len(embeddings[0])
        print(f"✅ save_vector_db: 임베딩 차원 = {dim}, 총 임베딩 수 = {len(embeddings)}")

        index = faiss.IndexFlatL2(dim)
        index.add(np.array(embeddings).astype("float32"))

        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        with open(db_path, "wb") as f:
            pickle.dump((index, metadata), f)

        print(f"✅ FAISS 인덱스 및 메타데이터 저장 완료: {db_path}")
    except Exception as e:
        print(f"❌ save_vector_db 실패: {e}")


def search_similar_chunks(query_embedding, top_k=3, db_path="backend/vector_db/faiss_db.pkl"):
    try:
        if not os.path.exists(db_path):
            print(f"❌ search_similar_chunks: 벡터 DB 파일이 존재하지 않음 → {db_path}")
            return []

        with open(db_path, "rb") as f:
            index, metadata = pickle.load(f)

        print(f"🔍 FAISS DB 로드 완료, 검색 시작... top_k = {top_k}")
        D, I = index.search(np.array([query_embedding]).astype("float32"), top_k)

        print(f"✅ 검색 완료: 인덱스 = {I[0]}, 거리 = {D[0]}")
        return [metadata[i] for i in I[0]]
    except Exception as e:
        print(f"❌ search_similar_chunks 실패: {e}")
        return []
