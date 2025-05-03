from pydantic import BaseModel
from typing import Optional

class HandwritingCreate(BaseModel):
    folder_id: int
    pdf_id: int
    page_number: int
    x: float
    y: float
    stroke_type: Optional[str] = "pen"
    color: Optional[str] = "#000000"
    thickness: Optional[float] = 1.0
