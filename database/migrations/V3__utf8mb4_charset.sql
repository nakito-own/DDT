ALTER DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE task_types CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE spaces CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE tasks CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE task_links CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE task_comments CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE ews_accounts CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE app_sessions CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Repair UTF-8 text that was stored as latin1 bytes (mojibake).
-- Repoint tasks away from duplicate mojibake rows before deduplication.
UPDATE tasks task
JOIN task_types bad ON task.type_id = bad.id
JOIN task_types good ON good.id <> bad.id
  AND good.name = CONVERT(CAST(CONVERT(bad.name USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci
SET task.type_id = good.id
WHERE CONVERT(CAST(CONVERT(bad.name USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci REGEXP '[А-Яа-яЁё]'
  AND bad.name NOT REGEXP '[А-Яа-яЁё]'
  AND good.name REGEXP '[А-Яа-яЁё]';

DELETE bad FROM task_types bad
INNER JOIN task_types good ON good.id <> bad.id
WHERE good.name = CONVERT(CAST(CONVERT(bad.name USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci
  AND CONVERT(CAST(CONVERT(bad.name USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci REGEXP '[А-Яа-яЁё]'
  AND bad.name NOT REGEXP '[А-Яа-яЁё]'
  AND good.name REGEXP '[А-Яа-яЁё]';

UPDATE task_types
SET name = CONVERT(CAST(CONVERT(name USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci
WHERE CONVERT(CAST(CONVERT(name USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci REGEXP '[А-Яа-яЁё]'
  AND name NOT REGEXP '[А-Яа-яЁё]';

UPDATE tasks
SET title = CONVERT(CAST(CONVERT(title USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci
WHERE CONVERT(CAST(CONVERT(title USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci REGEXP '[А-Яа-яЁё]'
  AND title NOT REGEXP '[А-Яа-яЁё]';

UPDATE tasks
SET description = CONVERT(CAST(CONVERT(description USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci
WHERE CONVERT(CAST(CONVERT(description USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci REGEXP '[А-Яа-яЁё]'
  AND description NOT REGEXP '[А-Яа-яЁё]';

UPDATE task_comments
SET text = CONVERT(CAST(CONVERT(text USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci
WHERE CONVERT(CAST(CONVERT(text USING latin1) AS BINARY) USING utf8mb4) COLLATE utf8mb4_unicode_ci REGEXP '[А-Яа-яЁё]'
  AND text NOT REGEXP '[А-Яа-яЁё]';

UPDATE task_types SET name = 'Задача' WHERE id = 1;
UPDATE task_types SET name = 'Баг' WHERE id = 2;
UPDATE task_types SET name = 'Улучшение' WHERE id = 3;
