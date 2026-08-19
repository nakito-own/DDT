CREATE TABLE IF NOT EXISTS spaces (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tasks'
    AND COLUMN_NAME = 'space_id'
);
SET @sql = IF(
  @col_exists = 0,
  'ALTER TABLE tasks ADD COLUMN space_id INT NULL AFTER owner_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @index_exists = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tasks'
    AND INDEX_NAME = 'idx_tasks_space_id'
);
SET @sql = IF(
  @index_exists = 0,
  'ALTER TABLE tasks ADD INDEX idx_tasks_space_id (space_id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists = (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tasks'
    AND CONSTRAINT_NAME = 'fk_tasks_space'
);
SET @sql = IF(
  @fk_exists = 0,
  'ALTER TABLE tasks ADD CONSTRAINT fk_tasks_space FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

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
