# backend/schemas/chatbot_schema.py

from pydantic import BaseModel

class ChatRequest(BaseModel):
    question: str
