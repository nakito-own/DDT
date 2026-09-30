from fastapi import APIRouter, Depends

from app.dependencies import get_current_session
from app.schemas.task import (
    CreateTaskCommentRequest,
    CreateTaskRequest,
    TaskCommentResponse,
    TaskResponse,
    UpdateTaskRequest,
    UpdateTaskStatusRequest,
)
from app.services.session_service import SessionContext
from app.services.task_service import (
    TaskNotFoundError,
    TaskRelationError,
    task_not_found,
    task_relation_error,
    task_service,
)

router = APIRouter()


@router.get("", response_model=list[TaskResponse])
async def list_tasks(context: SessionContext = Depends(get_current_session)):
    return task_service.list_tasks(context.user_id)


@router.post("", response_model=TaskResponse, status_code=201)
async def create_task(
    payload: CreateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.create_task(
            owner_id=context.user_id,
            author_id=context.user_id,
            payload=payload,
            username=context.username,
        )
    except TaskRelationError as exc:
        raise task_relation_error(exc) from exc
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.get("/{task_ref}", response_model=TaskResponse)
async def get_task(
    task_ref: str,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.get_task_by_ref(task_ref, context.user_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.post(
    "/{task_ref}/comments",
    response_model=TaskCommentResponse,
    status_code=201,
)
async def add_task_comment(
    task_ref: str,
    payload: CreateTaskCommentRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.add_comment_by_ref(
            task_ref=task_ref,
            user_id=context.user_id,
            text=payload.text,
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.put("/{task_ref}", response_model=TaskResponse)
async def update_task(
    task_ref: str,
    payload: UpdateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.update_task_by_ref(
            task_ref, context.user_id, payload
        )
    except TaskRelationError as exc:
        raise task_relation_error(exc) from exc
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.patch("/{task_ref}/status", response_model=TaskResponse)
async def update_task_status(
    task_ref: str,
    payload: UpdateTaskStatusRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return task_service.update_task_by_ref(
            task_ref,
            context.user_id,
            UpdateTaskRequest(status=payload.status),
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.delete("/{task_ref}", status_code=204)
async def delete_task(
    task_ref: str,
    context: SessionContext = Depends(get_current_session),
):
    try:
        task_service.delete_task_by_ref(task_ref, context.user_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc
