from fastapi import APIRouter, status
from fastapi.responses import JSONResponse

from app.db import get_db

router = APIRouter()


@router.get("")
async def health_check():
    try:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
        return {"status": "ok", "database": "connected"}
    except Exception:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "error", "database": "disconnected"},
        )
