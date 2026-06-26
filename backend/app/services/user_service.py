from dataclasses import dataclass

from app.db import get_db


@dataclass
class UserProfile:
    id: int
    name: str
    email: str
    display_name: str | None = None
    job_title: str | None = None
    department: str | None = None
    phone: str | None = None
    office_location: str | None = None
    ews_account_id: int | None = None


def _map_user_row(row) -> UserProfile:
    return UserProfile(
        id=row["id"],
        name=row["name"],
        email=row["email"],
        display_name=row.get("display_name"),
        job_title=row.get("job_title"),
        department=row.get("department"),
        phone=row.get("phone"),
        office_location=row.get("office_location"),
        ews_account_id=row.get("ews_account_id"),
    )


def user_profile_to_dict(user: UserProfile) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "display_name": user.display_name,
        "job_title": user.job_title,
        "department": user.department,
        "phone": user.phone,
        "office_location": user.office_location,
    }


class UserService:
    def get_by_id(self, user_id: int) -> UserProfile | None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, name, email, display_name, job_title, department,
                           phone, office_location, ews_account_id
                    FROM users
                    WHERE id = %s
                    """,
                    (user_id,),
                )
                row = cursor.fetchone()
        return _map_user_row(row) if row else None

    def get_by_email(self, email: str) -> UserProfile | None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, name, email, display_name, job_title, department,
                           phone, office_location, ews_account_id
                    FROM users
                    WHERE email = %s
                    """,
                    (email,),
                )
                row = cursor.fetchone()
        return _map_user_row(row) if row else None

    def upsert_from_exchange(
        self,
        *,
        email: str,
        display_name: str,
        job_title: str | None = None,
        department: str | None = None,
        phone: str | None = None,
        office_location: str | None = None,
        ews_account_id: int | None = None,
    ) -> UserProfile:
        name = display_name or email.split("@")[0]

        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO users
                      (name, display_name, email, job_title, department,
                       phone, office_location, ews_account_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                      name = VALUES(name),
                      display_name = VALUES(display_name),
                      job_title = VALUES(job_title),
                      department = VALUES(department),
                      phone = VALUES(phone),
                      office_location = VALUES(office_location),
                      ews_account_id = VALUES(ews_account_id)
                    """,
                    (
                        name,
                        display_name,
                        email,
                        job_title,
                        department,
                        phone,
                        office_location,
                        ews_account_id,
                    ),
                )
                cursor.execute(
                    """
                    SELECT id, name, email, display_name, job_title, department,
                           phone, office_location, ews_account_id
                    FROM users
                    WHERE email = %s
                    """,
                    (email,),
                )
                row = cursor.fetchone()

        if not row:
            raise RuntimeError("Failed to upsert user profile")

        return _map_user_row(row)


user_service = UserService()
