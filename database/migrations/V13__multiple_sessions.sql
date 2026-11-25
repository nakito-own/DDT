-- Several live sessions per Exchange account. A login from another device
-- or browser no longer replaces the sessions that are already open.
-- Device name, OS and IP country are stored with the login timestamp
-- (created_at) so the settings screen can list them.
--
-- The unique account index may be the only index behind the foreign key,
-- so the key is dropped and recreated around that index change.

SET @fk_name := (
  SELECT CONSTRAINT_NAME
  FROM information_schema.KEY_COLUMN_USAGE
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'app_sessions'
    AND COLUMN_NAME = 'ews_account_id'
    AND REFERENCED_TABLE_NAME IS NOT NULL
  LIMIT 1
);

SET @has_account_unique := (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'app_sessions'
    AND INDEX_NAME = 'uq_app_sessions_account'
);

SET @drop_fk := IF(
  @has_account_unique > 0 AND @fk_name IS NOT NULL,
  CONCAT('ALTER TABLE app_sessions DROP FOREIGN KEY `', @fk_name, '`'),
  'SELECT 1'
);

PREPARE drop_fk FROM @drop_fk;
EXECUTE drop_fk;
DEALLOCATE PREPARE drop_fk;

SET @drop_account_unique := IF(
  @has_account_unique > 0,
  'ALTER TABLE app_sessions DROP INDEX uq_app_sessions_account',
  'SELECT 1'
);

PREPARE drop_account_unique FROM @drop_account_unique;
EXECUTE drop_account_unique;
DEALLOCATE PREPARE drop_account_unique;

SET @has_account_index := (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'app_sessions'
    AND INDEX_NAME = 'idx_app_sessions_account'
);

SET @add_account_index := IF(
  @has_account_index = 0,
  'ALTER TABLE app_sessions ADD INDEX idx_app_sessions_account (ews_account_id)',
  'SELECT 1'
);

PREPARE add_account_index FROM @add_account_index;
EXECUTE add_account_index;
DEALLOCATE PREPARE add_account_index;

SET @fk_still := (
  SELECT COUNT(*)
  FROM information_schema.KEY_COLUMN_USAGE
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'app_sessions'
    AND COLUMN_NAME = 'ews_account_id'
    AND REFERENCED_TABLE_NAME IS NOT NULL
);

SET @add_fk := IF(
  @fk_still = 0,
  'ALTER TABLE app_sessions ADD CONSTRAINT fk_app_sessions_account FOREIGN KEY (ews_account_id) REFERENCES ews_accounts(id) ON DELETE CASCADE',
  'SELECT 1'
);

PREPARE add_fk FROM @add_fk;
EXECUTE add_fk;
DEALLOCATE PREPARE add_fk;

ALTER TABLE app_sessions
  ADD COLUMN device_name VARCHAR(255) NULL AFTER expires_at,
  ADD COLUMN os_name VARCHAR(128) NULL AFTER device_name,
  ADD COLUMN ip_country VARCHAR(128) NULL AFTER os_name;
