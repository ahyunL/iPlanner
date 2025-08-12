# services/text_splitter.py

def split_text_into_chunks(text: str, max_chunk_size=300, overlap=50):
    """
    긴 텍스트를 일정 길이로 겹치게 분할하는 함수
    예: 300자 단위, 겹침 50자
    """
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + max_chunk_size, len(text))
        chunks.append(text[start:end])
        start += max_chunk_size - overlap
    return chunks
