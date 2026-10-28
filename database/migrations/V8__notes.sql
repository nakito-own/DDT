CREATE TABLE notes (
  id CHAR(36) NOT NULL PRIMARY KEY,
  parent_id CHAR(36) NULL,
  kind ENUM('folder', 'note') NOT NULL,
  title VARCHAR(255) NOT NULL,
  body LONGTEXT NULL,
  author_id INT NULL,
  author_name VARCHAR(255) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_notes_parent FOREIGN KEY (parent_id) REFERENCES notes (id) ON DELETE CASCADE,
  CONSTRAINT fk_notes_author FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE SET NULL,
  INDEX idx_notes_parent (parent_id),
  INDEX idx_notes_updated_at (updated_at)
);
