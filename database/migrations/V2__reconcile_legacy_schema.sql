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

DELIMITER ;

CALL ddt_add_column_if_missing(
  'users',
  'display_name',
  'ALTER TABLE users ADD COLUMN display_name VARCHAR(255) NULL AFTER name'
);
CALL ddt_add_column_if_missing(
  'users',
  'job_title',
  'ALTER TABLE users ADD COLUMN job_title VARCHAR(255) NULL AFTER display_name'
);
CALL ddt_add_column_if_missing(
  'users',
  'department',
  'ALTER TABLE users ADD COLUMN department VARCHAR(255) NULL AFTER job_title'
);
CALL ddt_add_column_if_missing(
  'users',
  'phone',
  'ALTER TABLE users ADD COLUMN phone VARCHAR(50) NULL AFTER department'
);
CALL ddt_add_column_if_missing(
  'users',
  'office_location',
  'ALTER TABLE users ADD COLUMN office_location VARCHAR(255) NULL AFTER phone'
);
CALL ddt_add_column_if_missing(
  'users',
  'ews_account_id',
  'ALTER TABLE users ADD COLUMN ews_account_id INT NULL AFTER office_location'
);
CALL ddt_add_column_if_missing(
  'tasks',
  'owner_id',
  'ALTER TABLE tasks ADD COLUMN owner_id INT NULL AFTER responsible_id'
);
CALL ddt_add_column_if_missing(
  'tasks',
  'space_id',
  'ALTER TABLE tasks ADD COLUMN space_id INT NULL AFTER owner_id'
);

SET @space_index_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tasks'
    AND INDEX_NAME = 'idx_tasks_space_id'
);
SET @space_index_ddl = IF(
  @space_index_exists = 0,
  'ALTER TABLE tasks ADD INDEX idx_tasks_space_id (space_id)',
  'SELECT 1'
);
PREPARE statement FROM @space_index_ddl;
EXECUTE statement;
DEALLOCATE PREPARE statement;

CALL ddt_add_constraint_if_missing(
  'users',
  'fk_users_ews_account',
  'ALTER TABLE users ADD CONSTRAINT fk_users_ews_account FOREIGN KEY (ews_account_id) REFERENCES ews_accounts(id) ON DELETE SET NULL'
);
CALL ddt_add_constraint_if_missing(
  'tasks',
  'fk_tasks_owner',
  'ALTER TABLE tasks ADD CONSTRAINT fk_tasks_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE'
);
CALL ddt_add_constraint_if_missing(
  'tasks',
  'fk_tasks_space',
  'ALTER TABLE tasks ADD CONSTRAINT fk_tasks_space FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE'
);

UPDATE tasks AS task
JOIN spaces AS legacy_space
  ON legacy_space.id = task.space_id
  AND legacy_space.name IN ('тестовое', 'KRR MR')
JOIN spaces AS canonical_space
  ON canonical_space.name = CASE legacy_space.name
    WHEN 'тестовое' THEN 'TEST'
    WHEN 'KRR MR' THEN 'KRRMR'
  END
SET task.space_id = canonical_space.id;

DELETE legacy_space
FROM spaces AS legacy_space
JOIN spaces AS canonical_space
  ON canonical_space.name = CASE legacy_space.name
    WHEN 'тестовое' THEN 'TEST'
    WHEN 'KRR MR' THEN 'KRRMR'
  END
WHERE legacy_space.name IN ('тестовое', 'KRR MR');

UPDATE spaces
SET name = CASE name
  WHEN 'тестовое' THEN 'TEST'
  WHEN 'KRR MR' THEN 'KRRMR'
END
WHERE name IN ('тестовое', 'KRR MR');

INSERT INTO spaces (name) VALUES
  ('TEST'),
  ('KRRMR')
ON DUPLICATE KEY UPDATE name = VALUES(name);

DROP PROCEDURE ddt_add_column_if_missing;
DROP PROCEDURE ddt_add_constraint_if_missing;
