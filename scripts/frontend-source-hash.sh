#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

hash_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

while IFS= read -r -d '' file; do
  printf '%s  %s\n' "$(hash_file "$repo_root/$file")" "$file"
done < <(
  git -C "$repo_root" ls-files --cached --others --exclude-standard -z -- \
    frontend \
    ':!frontend/build/**'
) | LC_ALL=C sort | hash_stream
