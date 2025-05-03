from fastapi import APIRouter
from typing import List
from schemas.plan_schema import ToDoRequest, ToDoItem
from services.ai_planner import save_row_plans_to_db, generate_and_save_plans, create_plan_list_for_response

router = APIRouter()

@router.post("/todo", response_model=List[ToDoItem])
def generate_todo(request: ToDoRequest):
    save_row_plans_to_db(request.dict())
    generate_and_save_plans(request.user_id, request.subject_id)
    return create_plan_list_for_response(request.user_id, request.subject_id)
