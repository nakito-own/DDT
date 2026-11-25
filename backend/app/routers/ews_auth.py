from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials

from app.dependencies import bearer_scheme, get_current_session
from app.schemas.ews import (
    LoginRequest,
    LoginResponse,
    MeResponse,
    SessionDeviceListResponse,
    SessionDeviceRequest,
    SessionDeviceResponse,
    UserProfileResponse,
)
from app.services.client_device import resolve_device_labels
from app.services.ews_credentials import resolve_ews_username
from app.services.ews_runtime import EwsOverloadedError, run_blocking, run_ews
from app.services.ews_service import EwsAuthError, EwsConnectionError, ews_service
from app.services.geoip_service import client_ip, country_for_ip
from app.services.session_service import SessionContext, session_service, session_user_dict

router = APIRouter()


def _build_me_response(context: SessionContext, *, connected: bool) -> MeResponse:
    return MeResponse(
        email=context.email,
        connected=connected,
        remember_me=context.remember_me,
        expires_at=context.expires_at,
        user=UserProfileResponse(**session_user_dict(context)),
    )


def _device_from_request(
    request: Request, device_name: str | None, os_name: str | None
) -> tuple[str | None, str | None, str | None]:
    name, operating_system = resolve_device_labels(
        device_name,
        os_name,
        request.headers.get("user-agent"),
    )
    return name, operating_system, country_for_ip(client_ip(request))


def _session_list(context: SessionContext) -> SessionDeviceListResponse:
    if context.ews_account_id is None:
        return SessionDeviceListResponse(sessions=[])
    devices = session_service.list_account_sessions(
        context.ews_account_id, context.token_hash
    )
    return SessionDeviceListResponse(
        sessions=[
            SessionDeviceResponse(
                id=device.id,
                device_name=device.device_name,
                os_name=device.os_name,
                ip_country=device.ip_country,
                logged_in_at=device.logged_in_at,
                is_current=device.is_current,
            )
            for device in devices
        ]
    )


@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, request: Request):
    try:
        username = resolve_ews_username(str(payload.email), payload.username)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    device_name, os_name, ip_country = await run_blocking(
        _device_from_request,
        request,
        payload.device_name,
        payload.os_name,
    )

    try:
        token, context = await run_blocking(
            session_service.create_session,
            username,
            payload.password,
            str(payload.email),
            payload.remember_me,
            device_name,
            os_name,
            ip_country,
        )
    except EwsOverloadedError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except EwsAuthError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc
    except EwsConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Exchange authentication failed",
        ) from exc

    return LoginResponse(
        session_token=token,
        email=context.email,
        expires_at=context.expires_at,
        user=UserProfileResponse(**session_user_dict(context)),
    )


@router.get("/sessions", response_model=SessionDeviceListResponse)
def list_sessions(context: SessionContext = Depends(get_current_session)):
    return _session_list(context)


@router.post("/sessions/current", response_model=SessionDeviceListResponse)
async def describe_current_session(
    payload: SessionDeviceRequest,
    request: Request,
    context: SessionContext = Depends(get_current_session),
):
    """Store device metadata for a session opened before it was collected."""
    device_name, os_name, ip_country = await run_blocking(
        _device_from_request,
        request,
        payload.device_name,
        payload.os_name,
    )
    await run_blocking(
        session_service.remember_device_if_missing,
        context.token_hash,
        device_name,
        os_name,
        ip_country,
    )
    return await run_blocking(_session_list, context)


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_session(
    session_id: int,
    context: SessionContext = Depends(get_current_session),
):
    if context.ews_account_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    removed = session_service.delete_account_session(session_id, context.ews_account_id)
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
):
    if credentials is not None and credentials.scheme.lower() == "bearer":
        session_service.logout(credentials.credentials)


@router.post("/refresh", response_model=MeResponse)
async def refresh(context: SessionContext = Depends(get_current_session)):
    try:
        refreshed = await run_blocking(
            session_service.refresh_exchange_connection,
            context,
        )
        connected = True
    except EwsOverloadedError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except EwsAuthError as exc:
        session_service.delete_session(context.token_hash)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc
    except EwsConnectionError:
        return _build_me_response(context, connected=False)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Exchange session refresh failed",
        ) from exc

    return _build_me_response(refreshed, connected=connected)


@router.get("/me", response_model=MeResponse)
async def me(context: SessionContext = Depends(get_current_session)):
    connected = False
    try:
        await run_ews(context, ews_service.verify_account)
        await run_blocking(session_service.refresh_user_profile, context)
        connected = True
    except EwsConnectionError:
        connected = False

    return _build_me_response(context, connected=connected)
