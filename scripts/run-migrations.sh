#!/usr/bin/env bash
set -Eeuo pipefail

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:=3306}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "DB_NAME may contain only letters, numbers, and underscores" >&2
  exit 1
fi

export MYSQL_PWD="$DB_PASSWORD"
mysql_args=(
  --host="$DB_HOST"
  --port="$DB_PORT"
  --user="$DB_USER"
  --database="$DB_NAME"
  --batch
  --skip-column-names
)

for attempt in {1..60}; do
  if mysql "${mysql_args[@]}" --execute="SELECT 1" >/dev/null 2>&1; then
    break
  fi
  if ((attempt == 60)); then
    echo "MySQL did not become ready within 60 seconds" >&2
    exit 1
  fi
  sleep 1
done

mysql "${mysql_args[@]}" <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(64) PRIMARY KEY,
  filename VARCHAR(255) NOT NULL,
  checksum CHAR(64) NOT NULL,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
SQL

shopt -s nullglob
migrations=(/migrations/V[0-9]*__*.sql)
if ((${#migrations[@]} > 0)); then
  mapfile -d '' migrations < <(printf '%s\0' "${migrations[@]}" | sort -zV)
fi

if ((${#migrations[@]} == 0)); then
  echo "No migration files found" >&2
  exit 1
fi

for migration in "${migrations[@]}"; do
  filename="$(basename "$migration")"
  version="${filename%%__*}"
  version="${version#V}"
  checksum="$(sha256sum "$migration" | awk '{print $1}')"
  applied_checksum="$(
    mysql "${mysql_args[@]}" \
      --execute="SELECT checksum FROM schema_migrations WHERE version = '${version}'"
  )"

  if [[ -n "$applied_checksum" ]]; then
    if [[ "$applied_checksum" != "$checksum" ]]; then
      echo "Checksum mismatch for already applied migration $filename" >&2
      exit 1
    fi
    echo "Already applied: $filename"
    continue
  fi

  echo "Applying: $filename"
  mysql "${mysql_args[@]}" < "$migration"
  mysql "${mysql_args[@]}" --execute="
    INSERT INTO schema_migrations (version, filename, checksum)
    VALUES ('${version}', '${filename}', '${checksum}')
  "
done

echo "Database migrations are up to date"
