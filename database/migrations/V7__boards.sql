CREATE TABLE boards (
  id CHAR(36) NOT NULL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  author_id INT NULL,
  author_name VARCHAR(255) NOT NULL DEFAULT '',
  -- Diagram document. LONGTEXT is MySQL's CLOB: the nodeline project JSON.
  project_json LONGTEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_boards_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_boards_updated_at (updated_at),
  INDEX idx_boards_created_at (created_at)
);
