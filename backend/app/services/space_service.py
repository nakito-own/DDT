from app.db import get_db


class SpaceNotFoundError(Exception):
    pass


class SpaceService:
    def list_spaces(self) -> list[dict]:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, name, space_key, created_at
                    FROM spaces
                    ORDER BY id
                    """
                )
                return list(cursor.fetchall())

    def require_space(self, space_ref) -> dict:
        with get_db() as conn:
            with conn.cursor() as cursor:
                if isinstance(space_ref, int) or str(space_ref).isdigit():
                    cursor.execute(
                        """
                        SELECT id, name, space_key, created_at
                        FROM spaces
                        WHERE id = %s
                        """,
                        (int(space_ref),),
                    )
                else:
                    cursor.execute(
                        """
                        SELECT id, name, space_key, created_at
                        FROM spaces
                        WHERE space_key = %s
                        """,
                        (space_ref,),
                    )
                space = cursor.fetchone()
        if not space:
            raise SpaceNotFoundError
        return space


space_service = SpaceService()
