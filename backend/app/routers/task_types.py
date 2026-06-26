from fastapi import APIRouter, Depends

from app.dependencies import get_current_session
from app.schemas.task import TaskTypeResponse
from app.services.session_service import SessionContext
from app.services.task_service import task_service

router = APIRouter()


@router.get("", response_model=list[TaskTypeResponse])
async def list_task_types(_context: SessionContext = Depends(get_current_session)):
    return task_service.list_task_types()
