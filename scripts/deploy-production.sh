#!/usr/bin/env bash
set -Eeuo pipefail

if (($# != 2)); then
  echo "Usage: $0 DEPLOY_ROOT RELEASE_ID" >&2
  exit 1
fi

deploy_root="$1"
release_id="$2"
export RELEASE_ID="$release_id"
release_dir="$deploy_root/releases/$release_id"
shared_dir="$deploy_root/shared"
env_file="$shared_dir/.env"
backup_dir="$shared_dir/backups"
current_link="$deploy_root/current"

if [[ ! -f "$env_file" ]]; then
  echo "Production environment file is missing: $env_file" >&2
  exit 1
fi

if [[ ! -f "$release_dir/compose.production.yml" ]]; then
  echo "Invalid release directory: $release_dir" >&2
  exit 1
fi

mkdir -p "$backup_dir" "$release_dir/frontend/build/web"

cd "$release_dir"
./scripts/verify-frontend-release.sh --archive-only
rm -rf frontend/build/web
mkdir -p frontend/build/web
tar -xzf deploy/artifacts/frontend-web.tar.gz -C frontend/build/web

compose=(
  docker compose
  --project-name ddt
  --env-file "$env_file"
  --file "$release_dir/compose.production.yml"
)

previous_release=""
if [[ -L "$current_link" ]]; then
  previous_release="$(readlink "$current_link")"
fi

rollback() {
  exit_code=$?
  if ((exit_code == 0)); then
    return
  fi

  echo "Deployment failed; attempting to restore the previous application release" >&2
  if [[ -n "$previous_release" && -f "$previous_release/compose.production.yml" ]]; then
    previous_release_id="$(basename "$previous_release")"
    previous_compose=(
      docker compose
      --project-name ddt
      --env-file "$env_file"
      --file "$previous_release/compose.production.yml"
    )
    if ! RELEASE_ID="$previous_release_id" \
      "${previous_compose[@]}" up -d --remove-orphans backend frontend caddy; then
      RELEASE_ID="$previous_release_id" \
        "${previous_compose[@]}" build backend frontend || true
      RELEASE_ID="$previous_release_id" \
        "${previous_compose[@]}" up -d --remove-orphans backend frontend caddy || true
    fi
  else
    "${compose[@]}" stop backend frontend caddy || true
  fi
  exit "$exit_code"
}
trap rollback EXIT

"${compose[@]}" config --quiet
"${compose[@]}" build --pull backend frontend
"${compose[@]}" up -d --wait --wait-timeout 120 mysql

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="$backup_dir/ddt-$timestamp.sql.gz"
"${compose[@]}" exec -T mysql sh -c \
  'exec mysqldump --user=root --password="$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers "$MYSQL_DATABASE"' \
  | gzip -9 > "$backup_file"

"${compose[@]}" --profile migration run --rm migrate
"${compose[@]}" up -d --remove-orphans mysql backend frontend caddy

"${compose[@]}" exec -T backend python -c \
  "import urllib.request; urllib.request.urlopen('http://localhost:3000/api/health', timeout=10)"
"${compose[@]}" exec -T frontend wget -qO- http://127.0.0.1/api/health >/dev/null

ln -sfn "$release_dir" "$current_link"
find "$backup_dir" -type f -name 'ddt-*.sql.gz' -mtime +14 -delete

trap - EXIT
echo "Deployment $release_id completed successfully"
