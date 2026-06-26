from fastapi import APIRouter, Depends

from app.dependencies import get_current_session
from app.db import get_db
from app.services.session_service import SessionContext

router = APIRouter()


@router.get("")
async def list_users(_context: SessionContext = Depends(get_current_session)):
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, display_name, email, created_at
                FROM users
                ORDER BY name
                """
            )
            rows = cursor.fetchall()
    return rows
