from app.db import get_db


def ensure_space_schema() -> None:
    """Apply the small idempotent schema extension used by spaces."""
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS spaces (
                  id INT AUTO_INCREMENT PRIMARY KEY,
                  name VARCHAR(100) NOT NULL UNIQUE,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            cursor.execute(
                """
                SELECT COUNT(*) AS count
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'tasks'
                  AND COLUMN_NAME = 'space_id'
                """
            )
            if cursor.fetchone()["count"] == 0:
                cursor.execute(
                    "ALTER TABLE tasks ADD COLUMN space_id INT NULL AFTER owner_id"
                )
            cursor.execute(
                """
                SELECT COUNT(*) AS count
                FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'tasks'
                  AND INDEX_NAME = 'idx_tasks_space_id'
                """
            )
            if cursor.fetchone()["count"] == 0:
                cursor.execute(
                    "ALTER TABLE tasks ADD INDEX idx_tasks_space_id (space_id)"
                )
            cursor.execute(
                """
                SELECT COUNT(*) AS count
                FROM information_schema.TABLE_CONSTRAINTS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'tasks'
                  AND CONSTRAINT_NAME = 'fk_tasks_space'
                """
            )
            if cursor.fetchone()["count"] == 0:
                cursor.execute(
                    """
                    ALTER TABLE tasks
                    ADD CONSTRAINT fk_tasks_space
                    FOREIGN KEY (space_id) REFERENCES spaces(id)
                    ON DELETE CASCADE
                    """
                )
            cursor.execute(
                """
                UPDATE spaces
                SET name = CASE name
                  WHEN 'тестовое' THEN 'TEST'
                  WHEN 'KRR MR' THEN 'KRRMR'
                END
                WHERE name IN ('тестовое', 'KRR MR')
                """
            )
            cursor.execute(
                """
                INSERT INTO spaces (name) VALUES ('TEST'), ('KRRMR')
                ON DUPLICATE KEY UPDATE name = VALUES(name)
                """
            )
