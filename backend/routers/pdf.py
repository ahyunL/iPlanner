# FastAPI & Starlette
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, Form
from fastapi.responses import JSONResponse, Response
from typing import List
from uuid import uuid4

# DB / ORM
from sqlalchemy.orm import Session
from db import get_db

# 인증
from models.user import User
from utils.auth import get_current_user_id

# 모델 & 스키마
from models.pdf_folder import Folder
from models.pdf_notes import PdfNote
from models.pdf_pages import PdfPage
from models.pdf_annotations import PdfAnnotation

from schemas.pdf_schema import (
    PdfFolderCreate, PdfFolderOut,
    PdfNoteCreate, PdfNoteOut,
    PdfPageCreate, PdfPageOut,
    PdfAnnotationCreate, PdfAnnotationOut
)

from pydantic import BaseModel

# 썸네일 및 PDF 렌더링 유틸
from utils.thumbnail import generate_thumbnail
from utils.pdf_render import render_pdf_page

# 기타 유틸
import os
import fitz  # PyMuPDF


router = APIRouter(tags=["PDF"])




# 1. 폴더 생성
@router.post("/folders", response_model=PdfFolderOut)
def create_pdf_folder(
    folder: PdfFolderCreate,
    request: Request,
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)
    new_folder = Folder(name=folder.name, user_id=user_id)
    db.add(new_folder)
    db.commit()
    db.refresh(new_folder)
    return new_folder  #  FastAPI가 알아서 JSON으로 반환함 (utf-8 처리됨)
    

# 2. PDF 노트 생성 (빈 노트용)
@router.post("/notes", response_model=PdfNoteOut)
def create_pdf_note(note: PdfNoteCreate, db: Session = Depends(get_db)):
    new_note = PdfNote(
        title=note.title,
        file_path="/path/to/file.pdf",  # 빈 노트이므로 의미 없음
        total_pages=1,  # 기본 1페이지로 설정
        user_id=1,  # TODO: 실제 서비스에서는_id(request)
        folder_id=note.folder_id
    )
    db.add(new_note)
    db.commit()
    db.refresh(new_note)

    # 첫 번째 빈 페이지 자동 생성
    first_page = PdfPage(
        pdf_id=new_note.pdf_id,
        page_number=1,
        page_order=1,
        image_preview_url=None,
        aspect_ratio=None
    )
    db.add(first_page)
    db.commit()

    return new_note


# 3. 페이지 생성

@router.post("/pages", status_code=201)
def create_pdf_page(page: PdfPageCreate, db: Session = Depends(get_db)):
    # PDF 원본 경로 구하기
    pdf = db.query(PdfNote).filter(PdfNote.pdf_id == page.pdf_id).first()
    if not pdf:
        raise HTTPException(status_code=404, detail="PDF 노트를 찾을 수 없습니다.")

    pdf_path = pdf.file_path
    image_filename = f"thumb_{page.pdf_id}_{page.page_number}.png"
    image_path = f"static/thumbnails/{image_filename}"
    image_url = f"/static/thumbnails/{image_filename}"

    # 1. 비율 계산을 위한 PyMuPDF 열기
    try:
        doc = fitz.open(pdf_path)
        page_obj = doc[page.page_number - 1]
        width = page_obj.rect.width
        height = page_obj.rect.height
        aspect_ratio = round(width / height, 5)
        doc.close()
    except Exception as e:
        print(f"PDF 비율 계산 실패: {e}")
        aspect_ratio = None

    # 2. 썸네일 생성
    try:
        generate_thumbnail(pdf_path, page.page_number, image_path)
    except Exception as e:
        print(f"썸네일 생성 실패: {e}")
        image_url = None

    # 3. DB에 페이지 저장
    new_page = PdfPage(
        pdf_id=page.pdf_id,
        page_number=page.page_number,
        page_order=page.page_order or page.page_number,
        image_preview_url=image_url,
        aspect_ratio=aspect_ratio, 
    )
    db.add(new_page)
    db.commit()
    db.refresh(new_page)
    return {"page_id": new_page.page_id}



# 4. 필기 저장
@router.post("/annotations", response_model=PdfAnnotationOut)
def create_pdf_annotation(annotation: PdfAnnotationCreate, db: Session = Depends(get_db)):
    new_anno = PdfAnnotation(
        page_id=annotation.page_id,
        page_number=annotation.page_number,
        annotation_type=annotation.annotation_type,
        data=annotation.data
    )
    db.add(new_anno)
    db.commit()
    db.refresh(new_anno)
    return new_anno

# 5. 특정 페이지 필기 불러오기
@router.get("/annotations/{page_id}", response_model=list[PdfAnnotationOut])
def get_annotations_by_page(page_id: int, db: Session = Depends(get_db)):
    annotations = db.query(PdfAnnotation).filter(PdfAnnotation.page_id == page_id).all()
    return annotations

# 6. 특정 폴더의 PDF 목록 조회
@router.get("/notes/{folder_id}", response_model=list[PdfNoteOut])
def get_notes_by_folder(folder_id: int, db: Session = Depends(get_db)):
    notes = db.query(PdfNote).filter(PdfNote.folder_id == folder_id).all()
    return notes

# 7. 특정 PDF의 페이지 목록 조회
@router.get("/pages/{pdf_id}", response_model=list[PdfPageOut])
def get_pages_by_pdf(pdf_id: int, db: Session = Depends(get_db)):
    pages = db.query(PdfPage).filter(PdfPage.pdf_id == pdf_id).order_by(PdfPage.page_number).all()
    return pages


# 8. 모든 폴더 목록 조회
@router.get("/folders", response_model=List[PdfFolderOut])
def get_folders(request: Request, db: Session = Depends(get_db)):
    user_id = get_current_user_id(request)  # 토큰에서 user_id 추출
    folders = db.query(Folder).filter(Folder.user_id == user_id).all()
    return folders

# 9. 폴더 이름 수정
@router.patch("/folders/{folder_id}", response_model=PdfFolderOut)
def update_folder_name(
    folder_id: int,
    folder: PdfFolderCreate,  # folder.name 사용
    request: Request,
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)
    target = db.query(Folder).filter(Folder.folder_id == folder_id, Folder.user_id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="폴더를 찾을 수 없습니다.")
    target.name = folder.name  
    db.commit()
    db.refresh(target)
    return target


# 10. 폴더 삭제
@router.delete("/folders/{folder_id}", status_code=200)
def delete_folder(
    folder_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)
    folder = db.query(Folder).filter(Folder.folder_id == folder_id, Folder.user_id == user_id).first()
    if not folder:
        raise HTTPException(status_code=404, detail="폴더를 찾을 수 없습니다.")
    
    # PDF 노트, 페이지, 필기 등 자식 레코드도 제거 (옵션)
    db.query(PdfAnnotation).filter(PdfAnnotation.page_id.in_(
        db.query(PdfPage.page_id).filter(PdfPage.pdf_id.in_(
            db.query(PdfNote.pdf_id).filter(PdfNote.folder_id == folder_id)
        ))
    )).delete(synchronize_session=False)

    db.query(PdfPage).filter(PdfPage.pdf_id.in_(
        db.query(PdfNote.pdf_id).filter(PdfNote.folder_id == folder_id)
    )).delete(synchronize_session=False)

    db.query(PdfNote).filter(PdfNote.folder_id == folder_id).delete(synchronize_session=False)
    db.delete(folder)
    db.commit()
    return {"message": "폴더가 삭제되었습니다."}

# 11. 전체 pdf 노트에 대한 필기 일괄 조회
@router.get("/annotations/by_pdf/{pdf_id}", response_model=list[PdfAnnotationOut])
def get_annotations_by_pdf(pdf_id: int, db: Session = Depends(get_db)):
    annotations = (
        db.query(PdfAnnotation)
        .join(PdfPage, PdfAnnotation.page_id == PdfPage.page_id)
        .filter(PdfPage.pdf_id == pdf_id)
        .all()
    )
    return annotations


# 12. pdf 썸네일 업로드
@router.post("/thumbnails", response_model=dict)
def upload_thumbnail(
    page_id: int = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    try:
        print(f"썸네일 업로드 요청 도착 - page_id: {page_id}, filename: {file.filename}")

        ext = os.path.splitext(file.filename)[1]
        filename = f"thumb_{page_id}_{uuid4().hex[:8]}{ext}"
        save_path = f"static/thumbnails/{filename}"
        os.makedirs(os.path.dirname(save_path), exist_ok=True)

        with open(save_path, "wb") as buffer:
            buffer.write(file.file.read())
        print(f"썸네일 저장 완료: {save_path}")

        return {"thumbnail_path": f"/static/thumbnails/{filename}"}

    except Exception as e:
        print(f"썸네일 업로드 중 오류 발생: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)


    


# 13. 필기 삭제
@router.delete("/annotations/{page_id}")
def delete_annotations_by_page(
    page_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)
    page = db.query(PdfPage).filter(PdfPage.page_id == page_id).first()
    if not page:
        raise HTTPException(status_code=404, detail="Page not found")
    
    note = db.query(PdfNote).filter(PdfNote.pdf_id == page.pdf_id).first()
    if note.user_id != user_id:
        raise HTTPException(status_code=403, detail="Permission denied")

    deleted = db.query(PdfAnnotation).filter(PdfAnnotation.page_id == page_id).delete()
    db.commit()
    return {"deleted": deleted}


# 14. pdf 업로드
@router.post("/upload", response_model=PdfNoteOut)
def upload_pdf_file(
    title: str = Form(...),
    folder_id: int = Form(None),
    file: UploadFile = File(...),
    request: Request = None,
    db: Session = Depends(get_db),
):
    user_id = get_current_user_id(request)

    # 1️. 파일 저장
    ext = os.path.splitext(file.filename)[1].lower()
    if ext != ".pdf":
        raise HTTPException(status_code=400, detail="PDF 파일만 업로드할 수 있습니다.")

    pdf_filename = f"pdf_{uuid4().hex[:8]}.pdf"
    pdf_save_path = f"static/pdf/{pdf_filename}"
    os.makedirs(os.path.dirname(pdf_save_path), exist_ok=True)
    with open(pdf_save_path, "wb") as f_out:
        f_out.write(file.file.read())

    # 2. 페이지 수 확인 + 첫 페이지 비율 계산
    doc = fitz.open(pdf_save_path)
    total_pages = doc.page_count

    aspect_ratio = None
    if total_pages > 0:
        first_page = doc[0]
        width = first_page.rect.width
        height = first_page.rect.height
        if height != 0:
            aspect_ratio = round(width / height, 5)

    # 3. PdfNote DB 등록 (첫 페이지만 기준으로 비율 저장)
    new_note = PdfNote(
        title=title,
        file_path=pdf_save_path,
        total_pages=total_pages,
        user_id=user_id,
        folder_id=folder_id,
        aspect_ratio=aspect_ratio
    )
    db.add(new_note)
    db.commit()
    db.refresh(new_note)

    # 4. 각 페이지 PdfPage + 썸네일 + 개별 비율 저장
    for i in range(total_pages):
        image_filename = f"thumb_{new_note.pdf_id}_{i + 1}.png"
        image_path = f"static/thumbnails/{image_filename}"
        image_url = f"/static/thumbnails/{image_filename}"

        try:
            page_obj = doc[i]
            width = page_obj.rect.width
            height = page_obj.rect.height
            page_aspect_ratio = round(width / height, 5) if height != 0 else None

            generate_thumbnail(pdf_save_path, i + 1, image_path)

        except Exception as e:
            print(f"페이지 {i+1} 썸네일 생성 실패: {e}")
            image_url = None
            page_aspect_ratio = None

        new_page = PdfPage(
            pdf_id=new_note.pdf_id,
            page_number=i + 1,
            page_order=i + 1,
            image_preview_url=image_url,
            aspect_ratio=page_aspect_ratio,  # 각 페이지별 비율 저장
        )
        db.add(new_page)

    db.commit()
    return new_note



# 15. pdf 페이지 이미지 렌더링 (비율 포함)
@router.get("/page-image/{pdf_id}/{page_number}")
def get_pdf_page_image(pdf_id: int, page_number: int, db: Session = Depends(get_db)):
    pdf = db.query(PdfNote).filter(PdfNote.pdf_id == pdf_id).first()
    if not pdf:
        raise HTTPException(status_code=404, detail="PDF 노트를 찾을 수 없습니다.")
    
    print(f"Trying to open: {pdf.file_path}")  # 로그 추가

    # 절대경로 테스트
    import os
    abs_path = os.path.abspath(pdf.file_path)
    print(f"Absolute path: {abs_path}")
    if not os.path.exists(abs_path):
        raise HTTPException(status_code=500, detail="PDF 파일이 존재하지 않습니다.")

    result = render_pdf_page(abs_path, page_number)
    image_bytes = result["image_bytes"]
    aspect_ratio = result["aspect_ratio"]

    return Response(
        content=image_bytes,
        media_type="image/png",
        headers={"X-Aspect-Ratio": str(aspect_ratio)}
    )



# 16. PDF 노트 삭제 (노트 내 페이지, 필기 포함)
@router.delete("/notes/{pdf_id}", status_code=200)
def delete_pdf_note(
    pdf_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)

    # PDF 노트 조회 및 소유자 확인
    pdf_note = db.query(PdfNote).filter(PdfNote.pdf_id == pdf_id).first()
    if not pdf_note:
        raise HTTPException(status_code=404, detail="PDF 노트를 찾을 수 없습니다.")
    if pdf_note.user_id != user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다.")

    # 관련 필기 삭제
    db.query(PdfAnnotation).filter(PdfAnnotation.page_id.in_(
        db.query(PdfPage.page_id).filter(PdfPage.pdf_id == pdf_id)
    )).delete(synchronize_session=False)

    # 페이지 삭제
    db.query(PdfPage).filter(PdfPage.pdf_id == pdf_id).delete(synchronize_session=False)

    # 노트 삭제
    db.delete(pdf_note)
    db.commit()

    return {"message": "PDF 노트가 삭제되었습니다."}

# 17. 노트 다른 폴더로 이동
@router.patch("/notes/{note_id}", response_model=PdfNoteOut)
def update_note_folder(
    note_id: int,
    note_data: dict,  # 요청 바디에서 folder_id 받기
    request: Request,
    db: Session = Depends(get_db),
):
    user_id = get_current_user_id(request)

    note = db.query(PdfNote).filter(PdfNote.pdf_id == note_id, PdfNote.user_id == user_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="노트를 찾을 수 없습니다.")

    # folder_id만 갱신
    if "folder_id" in note_data:
        note.folder_id = note_data["folder_id"]

    db.commit()
    db.refresh(note)
    return note
