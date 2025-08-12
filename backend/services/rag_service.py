# services/rag_service.py

from services.embedding_service import get_embedding
from utils.vector_db_utils import search_similar_chunks

def retrieve_relevant_chunks(question: str, top_k=3) -> list[str]:
    q_embedding = get_embedding(question)
    if q_embedding is None:
        print("❌ 질문 임베딩 실패")
        return []

    chunks = search_similar_chunks(q_embedding, top_k=top_k)
    if not chunks:  # None 또는 빈 리스트 방어
        print("⚠️ 관련 청크 없음")
        return []

    return chunks
