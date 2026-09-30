from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials

from app.dependencies import bearer_scheme, get_current_session
from app.schemas.ews import LoginRequest, LoginResponse, MeResponse, UserProfileResponse
from app.services.ews_runtime import EwsOverloadedError, run_blocking, run_ews
from app.services.ews_service import EwsAuthError, EwsConnectionError, ews_service
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


@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest):
    try:
        token, context = await run_blocking(
            session_service.create_session,
            payload.username,
            payload.password,
            str(payload.email),
            payload.remember_me,
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


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
):
    if credentials is not None and credentials.scheme.lower() == "bearer":
        session_service.logout(credentials.credentials)


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
