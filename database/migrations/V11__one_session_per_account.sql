-- One live app session per Exchange account. Older logins for the same
-- account are dropped, then expired rows, then a unique key prevents them
-- from accumulating again.

DELETE FROM app_sessions
WHERE id NOT IN (
  SELECT id FROM (
    SELECT MAX(id) AS id
    FROM app_sessions
    GROUP BY ews_account_id
  ) keepers
);

DELETE FROM app_sessions
WHERE expires_at < UTC_TIMESTAMP();

SET @session_account_unique := (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'app_sessions'
    AND INDEX_NAME = 'uq_app_sessions_account'
);

SET @add_session_account_unique := IF(
  @session_account_unique = 0,
  'ALTER TABLE app_sessions ADD UNIQUE KEY uq_app_sessions_account (ews_account_id)',
  'SELECT 1'
);

PREPARE add_session_account_unique FROM @add_session_account_unique;
EXECUTE add_session_account_unique;
DEALLOCATE PREPARE add_session_account_unique;
