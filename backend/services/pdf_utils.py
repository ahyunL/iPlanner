import fitz  # PyMuPDF

def extract_text_from_pdf(pdf_path: str) -> str:
    """PDF 파일에서 전체 텍스트 추출"""
    text = ""
    try:
        doc = fitz.open(pdf_path)
        for page in doc:
            text += page.get_text()
    except Exception as e:
        print(f"⚠️ 텍스트 추출 오류: {e}")
    return text.strip()
