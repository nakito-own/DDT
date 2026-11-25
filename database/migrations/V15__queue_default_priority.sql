ALTER TABLE queue_settings
  ADD COLUMN default_priority ENUM(
    'insignificant',
    'low',
    'medium',
    'high',
    'blocker'
  ) NULL AFTER default_deadline_days;
