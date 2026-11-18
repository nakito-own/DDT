-- Two daily copies of dataset 28107: today and yesterday.
-- Older snapshot_date rows are removed after a successful daily fetch.

ALTER TABLE krr_work_versions
  MODIFY sync_generation INT NOT NULL DEFAULT 0,
  ADD COLUMN snapshot_date DATE NOT NULL DEFAULT '1970-01-01';

ALTER TABLE krr_work_versions
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (snapshot_date, id_unique);

CREATE TABLE krr_daily_snapshots (
  snapshot_date DATE NOT NULL PRIMARY KEY,
  dataset_id INT NOT NULL,
  dataset_name VARCHAR(512) NOT NULL DEFAULT '',
  total_count INT NOT NULL DEFAULT 0,
  stored_count INT NOT NULL DEFAULT 0,
  status VARCHAR(16) NOT NULL DEFAULT 'idle',
  error_message TEXT NULL,
  started_at TIMESTAMP NULL DEFAULT NULL,
  finished_at TIMESTAMP NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
