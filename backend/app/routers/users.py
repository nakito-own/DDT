from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile
from fastapi.responses import Response

from app.dependencies import get_current_session
from app.db import get_db
from app.services.avatar_service import MAX_AVATAR_BYTES, AvatarError, avatar_service
from app.services.session_service import SessionContext
from app.services.user_service import user_profile_to_dict, user_service

router = APIRouter()


@router.get("")
def list_users(_context: SessionContext = Depends(get_current_session)):
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, display_name, email, avatar_version, created_at
                FROM users
                ORDER BY name
                """
            )
            rows = cursor.fetchall()
    return rows


@router.post("/me/avatar")
async def upload_my_avatar(
    file: UploadFile = File(...),
    context: SessionContext = Depends(get_current_session),
):
    data = await file.read(MAX_AVATAR_BYTES + 1)
    await file.close()
    if len(data) > MAX_AVATAR_BYTES:
        raise HTTPException(status_code=413, detail="Файл слишком большой")
    try:
        avatar_service.save(context.user.id, data)
    except AvatarError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    user = user_service.bump_avatar_version(context.user.id)
    context.user = user
    return user_profile_to_dict(user)


@router.delete("/me/avatar")
def delete_my_avatar(context: SessionContext = Depends(get_current_session)):
    avatar_service.delete(context.user.id)
    user = user_service.set_avatar_version(context.user.id, None)
    context.user = user
    return user_profile_to_dict(user)


@router.get("/{user_id}/avatar")
def get_user_avatar(
    user_id: int,
    request: Request,
    size: int = Query(64, alias="s", ge=1, le=512),
    _version: int | None = Query(None, alias="v"),
    _context: SessionContext = Depends(get_current_session),
):
    found = avatar_service.read(user_id, size)
    if found is None:
        raise HTTPException(status_code=404, detail="Фотография не найдена")

    version, data = found
    etag = f'"{user_id}-{version}-{256 if size >= 128 else 64}"'
    headers = {
        "Cache-Control": "private, max-age=31536000, immutable",
        "ETag": etag,
        "Vary": "Authorization",
    }
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers=headers)
    return Response(content=data, media_type="image/webp", headers=headers)
