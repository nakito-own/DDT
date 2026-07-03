from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import get_current_session
from app.schemas.ews import (
    MailDetailResponse,
    MailFoldersResponse,
    MailSummaryResponse,
    MarkMailReadResponse,
    SendMailRequest,
    SendMailResponse,
)
from app.services.ews_service import EwsConnectionError, EwsNotFoundError, ews_service
from app.services.session_service import SessionContext, session_service

router = APIRouter()

MailFilterParam = Literal["all", "to_me", "flagged", "mentions"]
MailSortParam = Literal[
    "date_asc",
    "date_desc",
    "from",
    "to",
    "subject",
    "attachments",
    "importance",
]


def _ews_http_error(exc: Exception) -> HTTPException:
    if isinstance(exc, EwsNotFoundError):
        return HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )
    if isinstance(exc, EwsConnectionError):
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        )
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail="Failed to fetch mail from Exchange",
    )


@router.get("/folders", response_model=MailFoldersResponse)
async def mail_folders(context: SessionContext = Depends(get_current_session)):
    try:
        account = session_service.get_account(context)
        counts = ews_service.get_folder_counts(account)
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return MailFoldersResponse(**counts)


@router.get("/inbox", response_model=list[MailSummaryResponse])
async def inbox(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    mail_filter: MailFilterParam = Query(default="all", alias="filter"),
    sort: MailSortParam = Query(default="date_desc"),
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        messages = ews_service.list_inbox_messages(
            account,
            limit=limit,
            offset=offset,
            mail_filter=mail_filter,
            sort=sort,
            user_email=context.email,
        )
    except (EwsConnectionError, EwsNotFoundError) as exc:
        raise _ews_http_error(exc) from exc
    except Exception as exc:
        raise _ews_http_error(exc) from exc

    return [MailSummaryResponse(**message.__dict__) for message in messages]


@router.get("/messages/{message_id:path}", response_model=MailDetailResponse)
async def message_detail(
    message_id: str,
    mark_read: bool = Query(default=True),
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        message = ews_service.get_message(
            account, message_id, mark_read=mark_read
        )
    except EwsNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return MailDetailResponse(**message.__dict__)


@router.post("/messages/{message_id:path}/read", response_model=MarkMailReadResponse)
async def mark_message_read(
    message_id: str,
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        message = ews_service.mark_message_read(account, message_id)
    except EwsNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return MarkMailReadResponse(id=message.id, is_read=message.is_read)


@router.post("/send", response_model=SendMailResponse)
async def send_mail(
    payload: SendMailRequest,
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        ews_service.send_message(
            account=account,
            to=[str(email) for email in payload.to],
            cc=[str(email) for email in payload.cc],
            subject=payload.subject,
            body=payload.body,
        )
    except (EwsConnectionError, EwsNotFoundError) as exc:
        raise _ews_http_error(exc) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to send message via Exchange",
        ) from exc

    return SendMailResponse()
