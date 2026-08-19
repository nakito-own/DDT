from app.db import get_db


class SpaceNotFoundError(Exception):
    pass


class SpaceService:
    def list_spaces(self) -> list[dict]:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id, name, created_at FROM spaces ORDER BY id"
                )
                return list(cursor.fetchall())

    def require_space(self, space_id: int) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id, name, created_at FROM spaces WHERE id = %s",
                    (space_id,),
                )
                space = cursor.fetchone()
        if not space:
            raise SpaceNotFoundError
        return space


space_service = SpaceService()
