# backend/services/ocr_service.py
import os
from typing import List

def _extract_text_pymupdf(pdf_path: str) -> str:
    """PyMuPDF로 PDF 텍스트 추출 (가장 빠르고 안정적)"""
    try:
        import fitz  # PyMuPDF
        texts: List[str] = []
        with fitz.open(pdf_path) as doc:
            for page in doc:
                t = page.get_text("text") or ""
                if t.strip():
                    texts.append(t)
        joined = "\n\n".join(texts).strip()
        if joined:
            print("📝 PyMuPDF 텍스트 추출 사용")
        return joined
    except Exception as e:
        print(f"⚠️ PyMuPDF 실패: {e}")
        return ""

def _extract_text_paddleocr(pdf_path: str) -> str:
    """
    PaddleOCR 폴백: 이미지/스캔 PDF일 때만 사용.
    - OpenMP 중복 로드 충돌 완화 위해 지연 임포트
    - 최신 PaddleOCR API 호환: ocr.ocr(np.array(img))  (cls 인자 사용하지 않음)
    """
    try:
        # 일부 환경에서 OpenMP 충돌 회피(선택): 필요한 경우에만 켬
        # os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

        from paddleocr import PaddleOCR
        import fitz
        import numpy as np
        from PIL import Image

        print("🔁 PaddleOCR 폴백 사용")
        ocr = PaddleOCR(lang="korean", use_angle_cls=True, show_log=False)

        results: List[str] = []
        with fitz.open(pdf_path) as doc:
            # 해상도 살짝 업스케일
            zoom = 2.0
            mat = fitz.Matrix(zoom, zoom)
            for page in doc:
                pm = page.get_pixmap(matrix=mat)
                # 메모리 상 변환 (파일로 저장하지 않음)
                mode = "RGB" if pm.alpha == 0 else "RGBA"
                img = Image.frombytes(mode, [pm.width, pm.height], pm.samples)
                arr = np.array(img.convert("RGB"))
                # ✅ 최신 호환 API: cls 인자 미사용
                res = ocr.ocr(arr)

                # 결과 파싱(모델/버전에 따라 구조 달라서 방어적으로 처리)
                if isinstance(res, list):
                    for block in res:
                        if isinstance(block, list):
                            for line in block:
                                try:
                                    # line: [ box, (text, score) ]
                                    results.append(line[1][0])
                                except Exception:
                                    pass

        text = "\n".join(results).strip()
        return text
    except Exception as e:
        print(f"❌ OCR 실패: {e}")
        return ""

def extract_text_with_ocr_from_pdf(pdf_path: str, allow_ocr: bool = True) -> str:
    """
    1) PyMuPDF로 텍스트 먼저 시도
    2) 텍스트가 부족하고 allow_ocr=True이면 PaddleOCR 폴백
    """
    print(f"📌 OCR 함수 진입: {pdf_path}")

    # 1) 텍스트 PDF 우선
    text = _extract_text_pymupdf(pdf_path)
    if text:
        return text

    # 2) 폴백: 스캔/이미지 기반 PDF일 때만 OCR
    if allow_ocr:
        return _extract_text_paddleocr(pdf_path)

    # 3) OCR 비허용이면 빈 문자열 반환
    return ""

