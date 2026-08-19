from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import get_current_session
from app.schemas.space import SpaceResponse
from app.schemas.task import (
    CreateTaskCommentRequest,
    CreateTaskRequest,
    TaskCommentResponse,
    TaskResponse,
    UpdateTaskRequest,
    UpdateTaskStatusRequest,
)
from app.services.session_service import SessionContext
from app.services.space_service import (
    SpaceNotFoundError,
    space_service,
)
from app.services.task_service import TaskNotFoundError, task_not_found, task_service

router = APIRouter()


def _space_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Space not found",
    )


def _require_space(space_id: int) -> None:
    try:
        space_service.require_space(space_id)
    except SpaceNotFoundError as exc:
        raise _space_not_found() from exc


@router.get("", response_model=list[SpaceResponse])
async def list_spaces(_context: SessionContext = Depends(get_current_session)):
    return space_service.list_spaces()


@router.get("/{space_id}/tasks", response_model=list[TaskResponse])
async def list_space_tasks(
    space_id: int,
    _context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    return task_service.list_space_tasks(space_id)


@router.post("/{space_id}/tasks", response_model=TaskResponse, status_code=201)
async def create_space_task(
    space_id: int,
    payload: CreateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    return task_service.create_task(
        owner_id=context.user_id,
        author_id=context.user_id,
        payload=payload,
        space_id=space_id,
    )


@router.get("/{space_id}/tasks/{task_id}", response_model=TaskResponse)
async def get_space_task(
    space_id: int,
    task_id: int,
    _context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    try:
        return task_service.get_space_task(task_id, space_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.post(
    "/{space_id}/tasks/{task_id}/comments",
    response_model=TaskCommentResponse,
    status_code=201,
)
async def add_space_task_comment(
    space_id: int,
    task_id: int,
    payload: CreateTaskCommentRequest,
    context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    try:
        return task_service.add_comment(
            task_id=task_id,
            owner_id=context.user_id,
            author_id=context.user_id,
            text=payload.text,
            space_id=space_id,
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.put("/{space_id}/tasks/{task_id}", response_model=TaskResponse)
async def update_space_task(
    space_id: int,
    task_id: int,
    payload: UpdateTaskRequest,
    _context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    try:
        return task_service.update_task(
            task_id,
            owner_id=0,
            payload=payload,
            space_id=space_id,
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.patch("/{space_id}/tasks/{task_id}/status", response_model=TaskResponse)
async def update_space_task_status(
    space_id: int,
    task_id: int,
    payload: UpdateTaskStatusRequest,
    _context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    try:
        return task_service.update_task(
            task_id,
            owner_id=0,
            payload=UpdateTaskRequest(status=payload.status),
            space_id=space_id,
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.delete("/{space_id}/tasks/{task_id}", status_code=204)
async def delete_space_task(
    space_id: int,
    task_id: int,
    _context: SessionContext = Depends(get_current_session),
):
    _require_space(space_id)
    try:
        task_service.delete_task(task_id, owner_id=0, space_id=space_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc
