#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifact_dir="$repo_root/deploy/artifacts"
archive="$artifact_dir/frontend-web.tar.gz"
archive_only=false

if [[ "${1:-}" == "--archive-only" ]]; then
  archive_only=true
elif (($# > 0)); then
  echo "Usage: $0 [--archive-only]" >&2
  exit 1
fi

for required_file in \
  "$archive" \
  "$artifact_dir/frontend-web.sha256" \
  "$artifact_dir/frontend-source.sha256"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing frontend release file: $required_file" >&2
    echo "Run scripts/build-frontend-release.sh on the developer computer." >&2
    exit 1
  fi
done

if command -v sha256sum >/dev/null 2>&1; then
  actual_archive_hash="$(sha256sum "$archive" | awk '{print $1}')"
else
  actual_archive_hash="$(shasum -a 256 "$archive" | awk '{print $1}')"
fi

expected_archive_hash="$(tr -d '[:space:]' < "$artifact_dir/frontend-web.sha256")"
if [[ "$actual_archive_hash" != "$expected_archive_hash" ]]; then
  echo "Frontend archive checksum does not match frontend-web.sha256" >&2
  exit 1
fi

if [[ "$archive_only" == true ]]; then
  echo "Frontend release archive is valid"
  exit 0
fi

actual_source_hash="$("$repo_root/scripts/frontend-source-hash.sh")"
expected_source_hash="$(tr -d '[:space:]' < "$artifact_dir/frontend-source.sha256")"
if [[ "$actual_source_hash" != "$expected_source_hash" ]]; then
  echo "The committed frontend bundle is stale." >&2
  echo "Run scripts/build-frontend-release.sh and commit the refreshed artifact." >&2
  exit 1
fi

echo "Frontend release artifact is valid"
