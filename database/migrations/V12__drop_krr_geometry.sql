-- Polygons are no longer requested from DTW. Instant drop avoids rewriting
-- the table while the old LONGTEXT values are discarded.
ALTER TABLE krr_work_versions
  DROP COLUMN geometry_2d,
  ALGORITHM=INSTANT;
