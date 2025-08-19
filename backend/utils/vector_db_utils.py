# backend/utils/vector_db_utils.py
import os, pickle
import numpy as np
from services.embedding_service import SAVE_PATH  # 메타 pkl 경로

def _load_index_and_metadata(meta_pkl_path: str):
    """
    메타 파일 로드:
      - 신포맷: {"index_path": ".../faiss.index", "chunks": [...]}
      - (하위호환) 구포맷: {"index": serialized_bytes, "chunks": [...]}
      - (더 옛날) 튜플 (index, metadata) / index 단독
    """
    with open(meta_pkl_path, "rb") as f:
        obj = pickle.load(f)

    #  신규 포맷: 바이너리 파일 경로 우선
    if isinstance(obj, dict):
        if "index_path" in obj and obj["index_path"] and os.path.exists(obj["index_path"]):
            # 지연 임포트
            import faiss
            index = faiss.read_index(obj["index_path"])
            metadata = obj.get("chunks", [])
            return index, metadata

        # (하위호환) serialize_index로 저장된 바이트가 있는 경우
        if "index" in obj:
            try:
                import faiss  # 지연 임포트
                index = faiss.deserialize_index(obj["index"])
                metadata = obj.get("chunks", [])
                return index, metadata
            except Exception:
                pass

    #  튜플 (index, metadata)
    if isinstance(obj, tuple) and len(obj) == 2:
        # 이 경로는 pickle 언피클 중에 faiss를 자동 임포트할 수 있으므로
        # 필요시 여기서도 안전하게 보강
        try:
            import faiss  # 지연 임포트 (없어도 언피클 과정에서 로드될 수 있음)
        except Exception:
            pass
        index, metadata = obj
        return index, metadata

    # 아주 옛 포맷: index만
    return obj, []

def search_similar_chunks(query_embedding, top_k=3, db_path: str = SAVE_PATH):
    """
    쿼리 임베딩으로 유사 청크 검색
    """
    try:
        meta_path = os.path.abspath(db_path)
        if not os.path.exists(meta_path):
            print(f"❌ search_similar_chunks: 메타 pkl 없음 → {meta_path}")
            return []

        index, metadata = _load_index_and_metadata(meta_path)

        D, I = index.search(np.array([query_embedding], dtype="float32"), top_k)
        print(f"🔍 검색 완료: 인덱스={I[0]}, 거리={D[0]}")
        # 메타가 있으면 텍스트 반환, 없으면 인덱스 번호 반환
        return [metadata[i] if 0 <= i < len(metadata) else i for i in I[0]]
    except Exception as e:
        print(f"❌ search_similar_chunks 실패: {e}")
        return []


