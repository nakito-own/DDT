DELIMITER //

DROP PROCEDURE IF EXISTS ddt_add_column_if_missing//
CREATE PROCEDURE ddt_add_column_if_missing(
  IN target_table VARCHAR(64),
  IN target_column VARCHAR(64),
  IN alter_statement TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = target_table
      AND COLUMN_NAME = target_column
  ) THEN
    SET @ddl = alter_statement;
    PREPARE statement FROM @ddl;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;
  END IF;
END//

DROP PROCEDURE IF EXISTS ddt_add_constraint_if_missing//
CREATE PROCEDURE ddt_add_constraint_if_missing(
  IN target_table VARCHAR(64),
  IN target_constraint VARCHAR(64),
  IN alter_statement TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = target_table
      AND CONSTRAINT_NAME = target_constraint
  ) THEN
    SET @ddl = alter_statement;
    PREPARE statement FROM @ddl;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;
  END IF;
END//

DROP PROCEDURE IF EXISTS ddt_add_index_if_missing//
CREATE PROCEDURE ddt_add_index_if_missing(
  IN target_table VARCHAR(64),
  IN target_index VARCHAR(64),
  IN alter_statement TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = target_table
      AND INDEX_NAME = target_index
  ) THEN
    SET @ddl = alter_statement;
    PREPARE statement FROM @ddl;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;
  END IF;
END//

DELIMITER ;

CALL ddt_add_column_if_missing(
  'users',
  'username',
  'ALTER TABLE users ADD COLUMN username VARCHAR(100) NULL AFTER name'
);

CALL ddt_add_column_if_missing(
  'spaces',
  'space_key',
  'ALTER TABLE spaces ADD COLUMN space_key VARCHAR(64) NULL AFTER name'
);

CALL ddt_add_column_if_missing(
  'tasks',
  'task_key',
  'ALTER TABLE tasks ADD COLUMN task_key VARCHAR(191) NULL AFTER id'
);

CALL ddt_add_column_if_missing(
  'tasks',
  'key_prefix',
  'ALTER TABLE tasks ADD COLUMN key_prefix VARCHAR(100) NULL AFTER task_key'
);

CALL ddt_add_column_if_missing(
  'tasks',
  'task_number',
  'ALTER TABLE tasks ADD COLUMN task_number INT NULL AFTER key_prefix'
);

CALL ddt_add_column_if_missing(
  'tasks',
  'parent_id',
  'ALTER TABLE tasks ADD COLUMN parent_id INT NULL AFTER space_id'
);

UPDATE users AS u
JOIN (
  SELECT
    id,
    CASE
      WHEN LOWER(SUBSTRING_INDEX(email, '@', 1)) REGEXP '^[a-z0-9][a-z0-9._-]*$'
        THEN LOWER(SUBSTRING_INDEX(email, '@', 1))
      ELSE CONCAT('user', id)
    END AS base_username,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(SUBSTRING_INDEX(email, '@', 1))
      ORDER BY id
    ) AS duplicate_index
  FROM users
  WHERE username IS NULL OR username = ''
) AS numbered
  ON numbered.id = u.id
SET u.username = IF(
  numbered.duplicate_index = 1,
  numbered.base_username,
  CONCAT(numbered.base_username, numbered.id)
)
WHERE u.username IS NULL OR u.username = '';

UPDATE spaces
SET space_key = UPPER(REGEXP_REPLACE(name, '[^A-Za-z0-9]', ''))
WHERE space_key IS NULL OR space_key = '';

UPDATE spaces
SET space_key = CONCAT('SPACE', id)
WHERE space_key IS NULL OR space_key = '';

UPDATE tasks AS task
JOIN spaces AS space ON space.id = task.space_id
JOIN (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY space_id ORDER BY id) AS task_number
  FROM tasks
  WHERE space_id IS NOT NULL
    AND (task_key IS NULL OR task_key = '')
) AS numbered ON numbered.id = task.id
SET
  task.key_prefix = space.space_key,
  task.task_number = numbered.task_number,
  task.task_key = CONCAT(space.space_key, '-', numbered.task_number)
WHERE task.task_key IS NULL OR task.task_key = '';

UPDATE tasks AS task
JOIN users AS owner ON owner.id = task.owner_id
JOIN (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY id) AS task_number
  FROM tasks
  WHERE space_id IS NULL
    AND (task_key IS NULL OR task_key = '')
) AS numbered ON numbered.id = task.id
SET
  task.key_prefix = owner.username,
  task.task_number = numbered.task_number,
  task.task_key = CONCAT(owner.username, '-', numbered.task_number)
WHERE task.task_key IS NULL OR task.task_key = '';

UPDATE tasks
SET
  key_prefix = 'task',
  task_number = id,
  task_key = CONCAT('task-', id)
WHERE task_key IS NULL OR task_key = '';

CREATE TABLE IF NOT EXISTS task_key_counters (
  key_prefix VARCHAR(100) PRIMARY KEY,
  last_number INT NOT NULL
);

INSERT INTO task_key_counters (key_prefix, last_number)
SELECT key_prefix, MAX(task_number)
FROM tasks
WHERE key_prefix IS NOT NULL
GROUP BY key_prefix
ON DUPLICATE KEY UPDATE last_number = GREATEST(
  task_key_counters.last_number,
  VALUES(last_number)
);

CALL ddt_add_index_if_missing(
  'users',
  'uq_users_username',
  'ALTER TABLE users ADD UNIQUE INDEX uq_users_username (username)'
);

CALL ddt_add_index_if_missing(
  'spaces',
  'uq_spaces_space_key',
  'ALTER TABLE spaces ADD UNIQUE INDEX uq_spaces_space_key (space_key)'
);

CALL ddt_add_index_if_missing(
  'tasks',
  'uq_tasks_task_key',
  'ALTER TABLE tasks ADD UNIQUE INDEX uq_tasks_task_key (task_key)'
);

CALL ddt_add_index_if_missing(
  'tasks',
  'uq_tasks_key_prefix_number',
  'ALTER TABLE tasks ADD UNIQUE INDEX uq_tasks_key_prefix_number (key_prefix, task_number)'
);

CALL ddt_add_index_if_missing(
  'tasks',
  'idx_tasks_parent_id',
  'ALTER TABLE tasks ADD INDEX idx_tasks_parent_id (parent_id)'
);

CALL ddt_add_constraint_if_missing(
  'tasks',
  'fk_tasks_parent',
  'ALTER TABLE tasks ADD CONSTRAINT fk_tasks_parent FOREIGN KEY (parent_id) REFERENCES tasks(id) ON DELETE SET NULL'
);

DROP PROCEDURE ddt_add_column_if_missing;
DROP PROCEDURE ddt_add_constraint_if_missing;
DROP PROCEDURE ddt_add_index_if_missing;
