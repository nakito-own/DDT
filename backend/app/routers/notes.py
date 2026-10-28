from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import get_current_session
from app.schemas.note import (
    CreateNoteRequest,
    NoteResponse,
    NoteSummary,
    UpdateNoteRequest,
)
from app.services.note_service import (
    NoteNotFoundError,
    NotePayloadError,
    note_service,
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
        detail="Заметка не найдена",
    )


def _payload_error(exc: NotePayloadError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=exc.detail,
    )


@router.get("", response_model=list[NoteSummary])
def list_notes(_context: SessionContext = Depends(get_current_session)):
    return note_service.list_notes()


@router.post("", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
def create_note(
    payload: CreateNoteRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        return note_service.create_note(
            title=payload.title,
            kind=payload.kind,
            parent_id=payload.parent_id or None,
            author_id=context.user_id,
            author_name=_author_name(context),
        )
    except NotePayloadError as exc:
        raise _payload_error(exc) from exc


@router.get("/{note_id}", response_model=NoteResponse)
def get_note(
    note_id: str,
    _context: SessionContext = Depends(get_current_session),
):
    note = note_service.get_note(note_id)
    if note is None:
        raise _not_found()
    return note


@router.patch("/{note_id}", response_model=NoteResponse)
def update_note(
    note_id: str,
    payload: UpdateNoteRequest,
    _context: SessionContext = Depends(get_current_session),
):
    fields = payload.model_fields_set
    if not fields:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нечего сохранять",
        )
    try:
        return note_service.update_note(
            note_id,
            title=payload.title if "title" in fields else None,
            body=payload.body if "body" in fields else None,
            body_set="body" in fields,
            parent_id=(payload.parent_id or None) if "parent_id" in fields else None,
            parent_set="parent_id" in fields,
        )
    except NoteNotFoundError as exc:
        raise _not_found() from exc
    except NotePayloadError as exc:
        raise _payload_error(exc) from exc


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(
    note_id: str,
    _context: SessionContext = Depends(get_current_session),
):
    try:
        note_service.delete_note(note_id)
    except NoteNotFoundError as exc:
        raise _not_found() from exc
