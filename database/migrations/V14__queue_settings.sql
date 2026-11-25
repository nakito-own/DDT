-- Настройки очереди личных задач и каждого пространства.

CREATE TABLE IF NOT EXISTS queue_settings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  space_id INT NULL,
  owner_id INT NULL,
  default_status_id INT NULL,
  default_type_id INT NULL,
  default_deadline_days INT NULL,
  notify_assigned BOOLEAN NOT NULL DEFAULT TRUE,
  notify_updated BOOLEAN NOT NULL DEFAULT TRUE,
  notify_comment BOOLEAN NOT NULL DEFAULT TRUE,
  notify_deleted BOOLEAN NOT NULL DEFAULT TRUE,
  deadline_reminder_hours INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_queue_settings_space FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE,
  CONSTRAINT fk_queue_settings_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_queue_settings_space (space_id),
  UNIQUE KEY uq_queue_settings_owner (owner_id),
  CONSTRAINT chk_queue_settings_scope CHECK (
    (space_id IS NOT NULL AND owner_id IS NULL)
    OR (space_id IS NULL AND owner_id IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS queue_statuses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  queue_id INT NOT NULL,
  status_key VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,
  category ENUM('open', 'active', 'closed') NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_queue_statuses_queue FOREIGN KEY (queue_id) REFERENCES queue_settings(id) ON DELETE CASCADE,
  UNIQUE KEY uq_queue_status_key (queue_id, status_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS queue_task_types (
  id INT AUTO_INCREMENT PRIMARY KEY,
  queue_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_queue_task_types_queue FOREIGN KEY (queue_id) REFERENCES queue_settings(id) ON DELETE CASCADE,
  UNIQUE KEY uq_queue_task_type_name (queue_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS queue_fields (
  id INT AUTO_INCREMENT PRIMARY KEY,
  queue_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  field_type ENUM('text', 'number', 'date', 'list', 'user', 'checkbox') NOT NULL,
  list_multiple BOOLEAN NOT NULL DEFAULT FALSE,
  options_json JSON NULL,
  default_value_json JSON NULL,
  sort_order INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_queue_fields_queue FOREIGN KEY (queue_id) REFERENCES queue_settings(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS task_field_values (
  task_id INT NOT NULL,
  field_id INT NOT NULL,
  value_json JSON NULL,
  PRIMARY KEY (task_id, field_id),
  CONSTRAINT fk_task_field_values_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  CONSTRAINT fk_task_field_values_field FOREIGN KEY (field_id) REFERENCES queue_fields(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS queue_components (
  id INT AUTO_INCREMENT PRIMARY KEY,
  queue_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_queue_components_queue FOREIGN KEY (queue_id) REFERENCES queue_settings(id) ON DELETE CASCADE,
  UNIQUE KEY uq_queue_component_name (queue_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS queue_default_components (
  queue_id INT NOT NULL,
  component_id INT NOT NULL,
  PRIMARY KEY (queue_id, component_id),
  CONSTRAINT fk_queue_default_components_queue FOREIGN KEY (queue_id) REFERENCES queue_settings(id) ON DELETE CASCADE,
  CONSTRAINT fk_queue_default_components_component FOREIGN KEY (component_id) REFERENCES queue_components(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS task_components (
  task_id INT NOT NULL,
  component_id INT NOT NULL,
  PRIMARY KEY (task_id, component_id),
  CONSTRAINT fk_task_components_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  CONSTRAINT fk_task_components_component FOREIGN KEY (component_id) REFERENCES queue_components(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS task_notification_settings (
  task_id INT NOT NULL PRIMARY KEY,
  notify_assigned BOOLEAN NOT NULL DEFAULT TRUE,
  notify_updated BOOLEAN NOT NULL DEFAULT TRUE,
  notify_comment BOOLEAN NOT NULL DEFAULT TRUE,
  notify_deleted BOOLEAN NOT NULL DEFAULT TRUE,
  deadline_reminder_hours INT NULL,
  reminder_deadline DATETIME NULL,
  reminder_hours INT NULL,
  CONSTRAINT fk_task_notification_settings_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO queue_settings (space_id)
SELECT s.id
FROM spaces s
WHERE NOT EXISTS (
  SELECT 1 FROM queue_settings q WHERE q.space_id = s.id
);

INSERT INTO queue_settings (owner_id)
SELECT DISTINCT t.owner_id
FROM tasks t
WHERE t.space_id IS NULL
  AND t.owner_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM queue_settings q WHERE q.owner_id = t.owner_id
  );

INSERT INTO queue_statuses (queue_id, status_key, name, category, sort_order, is_system)
SELECT q.id, seed.status_key, seed.name, seed.category, seed.sort_order, TRUE
FROM queue_settings q
JOIN (
  SELECT 'todo' AS status_key, 'Запланировано' AS name, 'open' AS category, 0 AS sort_order
  UNION ALL SELECT 'in_progress', 'В работе', 'active', 1
  UNION ALL SELECT 'done', 'Готово', 'closed', 2
) seed
WHERE NOT EXISTS (
  SELECT 1
  FROM queue_statuses existing
  WHERE existing.queue_id = q.id
    AND existing.status_key = seed.status_key
);

INSERT INTO queue_task_types (queue_id, name, sort_order)
SELECT q.id, types.name, types.sort_order
FROM queue_settings q
JOIN (
  SELECT name, id AS sort_order
  FROM task_types
) types
WHERE NOT EXISTS (
  SELECT 1
  FROM queue_task_types existing
  WHERE existing.queue_id = q.id
    AND existing.name = types.name
);

INSERT INTO queue_task_types (queue_id, name, sort_order)
SELECT q.id, seed.name, seed.sort_order
FROM queue_settings q
JOIN (
  SELECT 'Задача' AS name, 0 AS sort_order
  UNION ALL SELECT 'Баг', 1
  UNION ALL SELECT 'Улучшение', 2
) seed
WHERE NOT EXISTS (
  SELECT 1 FROM queue_task_types existing WHERE existing.queue_id = q.id
)
AND NOT EXISTS (
  SELECT 1
  FROM queue_task_types existing
  WHERE existing.queue_id = q.id
    AND existing.name = seed.name
);

UPDATE queue_settings q
JOIN queue_statuses s ON s.queue_id = q.id AND s.status_key = 'todo'
SET q.default_status_id = s.id
WHERE q.default_status_id IS NULL;

UPDATE queue_settings q
JOIN queue_task_types t ON t.queue_id = q.id AND t.name = 'Задача'
SET q.default_type_id = t.id
WHERE q.default_type_id IS NULL;

UPDATE queue_settings q
JOIN queue_task_types t ON t.queue_id = q.id
SET q.default_type_id = t.id
WHERE q.default_type_id IS NULL
  AND t.id = (
    SELECT MIN(inner_type.id)
    FROM queue_task_types inner_type
    WHERE inner_type.queue_id = q.id
  );

ALTER TABLE tasks ADD COLUMN queue_type_id INT NULL;

UPDATE tasks task
JOIN task_types old_type ON old_type.id = task.type_id
JOIN queue_settings q ON q.space_id = task.space_id
JOIN queue_task_types new_type
  ON new_type.queue_id = q.id
 AND new_type.name = old_type.name
SET task.queue_type_id = new_type.id
WHERE task.space_id IS NOT NULL;

UPDATE tasks task
JOIN task_types old_type ON old_type.id = task.type_id
JOIN queue_settings q ON q.owner_id = task.owner_id AND q.space_id IS NULL
JOIN queue_task_types new_type
  ON new_type.queue_id = q.id
 AND new_type.name = old_type.name
SET task.queue_type_id = new_type.id
WHERE task.space_id IS NULL;

DROP PROCEDURE IF EXISTS ddt_drop_tasks_type_fk;
DELIMITER //
CREATE PROCEDURE ddt_drop_tasks_type_fk()
BEGIN
  DECLARE fk_name VARCHAR(64) DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET fk_name = NULL;
  SELECT CONSTRAINT_NAME INTO fk_name
  FROM information_schema.KEY_COLUMN_USAGE
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tasks'
    AND COLUMN_NAME = 'type_id'
    AND REFERENCED_TABLE_NAME IS NOT NULL
  LIMIT 1;
  IF fk_name IS NOT NULL THEN
    SET @ddl = CONCAT('ALTER TABLE tasks DROP FOREIGN KEY `', fk_name, '`');
    PREPARE statement FROM @ddl;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;
  END IF;
END//
DELIMITER ;

CALL ddt_drop_tasks_type_fk();
DROP PROCEDURE IF EXISTS ddt_drop_tasks_type_fk;

UPDATE tasks SET type_id = queue_type_id;
ALTER TABLE tasks DROP COLUMN queue_type_id;

ALTER TABLE tasks
  ADD CONSTRAINT fk_tasks_queue_type
  FOREIGN KEY (type_id) REFERENCES queue_task_types(id) ON DELETE SET NULL;
