from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import get_current_session
from app.schemas.board import (
    BoardResponse,
    BoardSummary,
    CreateBoardRequest,
    UpdateBoardRequest,
)
from app.services.board_service import (
    BoardNotFoundError,
    BoardPayloadError,
    board_service,
)
from app.services.session_service import SessionContext

router = APIRouter()


def _author_name(context: SessionContext) -> str:
    user = context.user
    name = (user.display_name or user.name or "").strip()
    return (name or user.email)[:255]


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Board not found",
    )


@router.get("", response_model=list[BoardSummary])
def list_boards(_context: SessionContext = Depends(get_current_session)):
    return board_service.list_boards()


@router.post("", response_model=BoardResponse, status_code=status.HTTP_201_CREATED)
def create_board(
    payload: CreateBoardRequest,
    context: SessionContext = Depends(get_current_session),
):
    return board_service.create_board(
        title=payload.title,
        author_id=context.user_id,
        author_name=_author_name(context),
    )


@router.get("/{board_id}", response_model=BoardResponse)
def get_board(
    board_id: str,
    _context: SessionContext = Depends(get_current_session),
):
    board = board_service.get_board(board_id)
    if board is None:
        raise _not_found()
    return board


@router.patch("/{board_id}", response_model=BoardResponse)
def update_board(
    board_id: str,
    payload: UpdateBoardRequest,
    _context: SessionContext = Depends(get_current_session),
):
    fields = payload.model_fields_set
    if "title" not in fields and "project" not in fields:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nothing to update",
        )
    try:
        return board_service.update_board(
            board_id,
            title=payload.title if "title" in fields else None,
            project=payload.project if "project" in fields else None,
            project_set="project" in fields,
        )
    except BoardNotFoundError as exc:
        raise _not_found() from exc
    except BoardPayloadError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=exc.detail,
        ) from exc


@router.delete("/{board_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_board(
    board_id: str,
    _context: SessionContext = Depends(get_current_session),
):
    try:
        board_service.delete_board(board_id)
    except BoardNotFoundError as exc:
        raise _not_found() from exc
