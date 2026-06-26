from fastapi import APIRouter, Depends

from app.dependencies import get_current_session
from app.schemas.task import (
    CreateTaskRequest,
    TaskResponse,
    TaskTypeResponse,
    UpdateTaskRequest,
    UpdateTaskStatusRequest,
)
from app.services.session_service import SessionContext
from app.services.task_service import TaskNotFoundError, task_not_found, task_service

router = APIRouter()


@router.get("", response_model=list[TaskResponse])
async def list_tasks(context: SessionContext = Depends(get_current_session)):
    return task_service.list_tasks(context.user_id)


@router.post("", response_model=TaskResponse, status_code=201)
async def create_task(
    payload: CreateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    return task_service.create_task(
        owner_id=context.user_id,
        author_id=context.user_id,
        payload=payload,
    )


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: int,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.get_task(task_id, context.user_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.put("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: int,
    payload: UpdateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.update_task(task_id, context.user_id, payload)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.patch("/{task_id}/status", response_model=TaskResponse)
async def update_task_status(
    task_id: int,
    payload: UpdateTaskStatusRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.update_task(
            task_id,
            context.user_id,
            UpdateTaskRequest(status=payload.status),
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.delete("/{task_id}", status_code=204)
async def delete_task(
    task_id: int,
    context: SessionContext = Depends(get_current_session),
):
    try:
        task_service.delete_task(task_id, context.user_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc
