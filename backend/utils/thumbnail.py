# backend/utils/thumbnail.py

import fitz  # PyMuPDF
import os

def generate_thumbnail(pdf_path: str, page_number: int, output_path: str, base_height: int = 400):
    doc = fitz.open(pdf_path)
    page = doc[page_number - 1]

    # 📏 원본 비율 계산
    width = page.rect.width
    height = page.rect.height
    aspect_ratio = width / height

    # 🎯 기준 높이 설정 (base_height), 너비는 비율에 맞게 자동 조정
    target_height = base_height
    target_width = int(target_height * aspect_ratio)

    # 🧮 비율에 맞는 확대 비율 계산
    zoom_x = target_width / width
    zoom_y = target_height / height
    matrix = fitz.Matrix(zoom_x, zoom_y)

    # ✅ 렌더링 (배경 흰색, 여백 없음)
    pix = page.get_pixmap(matrix=matrix, alpha=False)

    # 저장
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    pix.save(output_path)
    doc.close()
