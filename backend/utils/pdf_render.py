# utils/pdf_render.py

import fitz  # PyMuPDF
from fastapi import HTTPException

def render_pdf_page(pdf_path: str, page_number: int) -> dict:
    """
    지정된 PDF 경로에서 특정 페이지를 렌더링하여 이미지 바이트와 종횡비를 반환한다.

    Returns:
        dict: {
            "image_bytes": PNG 이미지 바이트,
            "aspect_ratio": 높이 / 너비
        }
    """
    try:
        doc = fitz.open(pdf_path)
        if page_number < 1 or page_number > doc.page_count:
            raise HTTPException(status_code=400, detail="Invalid page number")

        page = doc.load_page(page_number - 1)
        width = page.rect.width
        height = page.rect.height
        aspect_ratio = height / width if width != 0 else 1.0

        # 비율에 따라 동적 matrix 설정 (기본 해상도 기준)
        scale_factor = 2.0  # 필요에 따라 조절
        matrix = fitz.Matrix(scale_factor, scale_factor)
        pix = page.get_pixmap(matrix=matrix)

        return {
            "image_bytes": pix.tobytes("png"),
            "aspect_ratio": round(aspect_ratio, 4),
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF 렌더링 실패: {e}")
