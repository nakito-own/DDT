from typing import Literal
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse

from app.dependencies import get_current_session
from app.schemas.ews import (
    ArchiveMailRequest,
    ArchiveMailResponse,
    MailAttachmentResponse,
    MailFolderResponse,
    MailDetailResponse,
    MailFoldersResponse,
    MailSummaryResponse,
    MarkMailReadResponse,
    SendMailRequest,
    SendMailResponse,
)
from app.services.ews_service import EwsConnectionError, EwsNotFoundError, MailDetail, ews_service
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


def _folder_response(folder: object) -> MailFolderResponse:
    data = folder.__dict__
    return MailFolderResponse(
        id=data["id"],
        name=data["name"],
        total_count=data["total_count"],
        unread_count=data["unread_count"],
        children=[_folder_response(child) for child in data["children"]],
    )


def _detail_response(message: MailDetail) -> MailDetailResponse:
    return MailDetailResponse(
        id=message.id,
        folder_id=message.folder_id,
        subject=message.subject,
        sender=message.sender,
        datetime_received=message.datetime_received,
        is_read=message.is_read,
        preview=message.preview,
        has_attachments=message.has_attachments,
        body=message.body,
        body_type=message.body_type,
        attachments=[
            MailAttachmentResponse(
                id=att.id,
                name=att.name,
                size=att.size,
                content_type=att.content_type,
            )
            for att in message.attachments
        ],
    )


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
        folders = ews_service.list_mail_folders(account)
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return MailFoldersResponse(
        **counts,
        folders=[_folder_response(folder) for folder in folders],
    )


@router.get("/inbox", response_model=list[MailSummaryResponse])
async def inbox(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    mail_filter: MailFilterParam = Query(default="all", alias="filter"),
    sort: MailSortParam = Query(default="date_desc"),
    folder_id: str | None = Query(default=None),
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
            folder_id=folder_id,
        )
    except (EwsConnectionError, EwsNotFoundError) as exc:
        raise _ews_http_error(exc) from exc
    except Exception as exc:
        raise _ews_http_error(exc) from exc

    return [MailSummaryResponse(**message.__dict__) for message in messages]


@router.get("/messages/{message_id:path}/attachment")
async def download_attachment(
    message_id: str,
    attachment_id: str = Query(...),
    folder_id: str | None = Query(default=None),
    context: SessionContext = Depends(get_current_session),
) -> StreamingResponse:
    try:
        account = session_service.get_account(context)
        content, filename, content_type = ews_service.get_attachment(
            account,
            message_id,
            attachment_id,
            folder_id=folder_id,
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

    encoded_name = quote(filename, safe="")
    disposition = f"attachment; filename*=UTF-8''{encoded_name}"

    async def _iter_chunks(data: bytes, chunk: int = 65536):
        for i in range(0, len(data), chunk):
            yield data[i : i + chunk]

    return StreamingResponse(
        _iter_chunks(content),
        media_type=content_type,
        headers={
            "Content-Disposition": disposition,
            "Content-Length": str(len(content)),
        },
    )


@router.get("/messages/{message_id:path}", response_model=MailDetailResponse)
async def message_detail(
    message_id: str,
    mark_read: bool = Query(default=True),
    folder_id: str | None = Query(default=None),
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        message = ews_service.get_message(
            account, message_id, mark_read=mark_read, folder_id=folder_id
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

    return _detail_response(message)


@router.post("/messages/{message_id:path}/read", response_model=MarkMailReadResponse)
async def mark_message_read(
    message_id: str,
    folder_id: str | None = Query(default=None),
    context: SessionContext = Depends(get_current_session),
):
    try:
        account = session_service.get_account(context)
        message = ews_service.mark_message_read(
            account, message_id, folder_id=folder_id
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


@router.post("/archive", response_model=ArchiveMailResponse)
async def archive_messages(
    payload: ArchiveMailRequest,
    context: SessionContext = Depends(get_current_session),
) -> ArchiveMailResponse:
    try:
        account = session_service.get_account(context)
        archived_ids, errors = ews_service.archive_messages(
            account,
            message_ids=payload.message_ids,
            folder_id=payload.folder_id,
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

    return ArchiveMailResponse(archived_ids=archived_ids, errors=errors)
