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
from app.services.task_service import (
    TaskNotFoundError,
    TaskRelationError,
    task_not_found,
    task_relation_error,
    task_service,
)

router = APIRouter()


def _space_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Space not found",
    )


def _require_space(space_ref: str) -> dict:
    try:
        return space_service.require_space(space_ref)
    except SpaceNotFoundError as exc:
        raise _space_not_found() from exc


@router.get("", response_model=list[SpaceResponse])
async def list_spaces(_context: SessionContext = Depends(get_current_session)):
    return space_service.list_spaces()


@router.get("/{space_ref}/tasks", response_model=list[TaskResponse])
async def list_space_tasks(
    space_ref: str,
    _context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    return task_service.list_space_tasks(space["id"])


@router.post("/{space_ref}/tasks", response_model=TaskResponse, status_code=201)
async def create_space_task(
    space_ref: str,
    payload: CreateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    try:
        return task_service.create_task(
            owner_id=context.user_id,
            author_id=context.user_id,
            payload=payload,
            space_id=space["id"],
            username=context.username,
        )
    except TaskRelationError as exc:
        raise task_relation_error(exc) from exc
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.get("/{space_ref}/tasks/{task_ref}", response_model=TaskResponse)
async def get_space_task(
    space_ref: str,
    task_ref: str,
    context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    try:
        task = task_service.get_task_by_ref(task_ref, context.user_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc
    if task.get("space_id") != space["id"]:
        raise task_not_found()
    return task


@router.post(
    "/{space_ref}/tasks/{task_ref}/comments",
    response_model=TaskCommentResponse,
    status_code=201,
)
async def add_space_task_comment(
    space_ref: str,
    task_ref: str,
    payload: CreateTaskCommentRequest,
    context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    try:
        task = task_service.get_task_by_ref(task_ref, context.user_id)
        if task.get("space_id") != space["id"]:
            raise TaskNotFoundError
        return task_service.add_comment_by_ref(
            task_ref=task_ref,
            user_id=context.user_id,
            text=payload.text,
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.put("/{space_ref}/tasks/{task_ref}", response_model=TaskResponse)
async def update_space_task(
    space_ref: str,
    task_ref: str,
    payload: UpdateTaskRequest,
    context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    try:
        task = task_service.get_task_by_ref(task_ref, context.user_id)
        if task.get("space_id") != space["id"]:
            raise TaskNotFoundError
        return task_service.update_task_by_ref(
            task_ref, context.user_id, payload
        )
    except TaskRelationError as exc:
        raise task_relation_error(exc) from exc
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.patch("/{space_ref}/tasks/{task_ref}/status", response_model=TaskResponse)
async def update_space_task_status(
    space_ref: str,
    task_ref: str,
    payload: UpdateTaskStatusRequest,
    context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    try:
        task = task_service.get_task_by_ref(task_ref, context.user_id)
        if task.get("space_id") != space["id"]:
            raise TaskNotFoundError
        return task_service.update_task_by_ref(
            task_ref,
            context.user_id,
            UpdateTaskRequest(status=payload.status),
        )
    except TaskNotFoundError as exc:
        raise task_not_found() from exc


@router.delete("/{space_ref}/tasks/{task_ref}", status_code=204)
async def delete_space_task(
    space_ref: str,
    task_ref: str,
    context: SessionContext = Depends(get_current_session),
):
    space = _require_space(space_ref)
    try:
        task = task_service.get_task_by_ref(task_ref, context.user_id)
        if task.get("space_id") != space["id"]:
            raise TaskNotFoundError
        task_service.delete_task_by_ref(task_ref, context.user_id)
    except TaskNotFoundError as exc:
        raise task_not_found() from exc
