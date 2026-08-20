#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifact_dir="$repo_root/deploy/artifacts"
archive="$artifact_dir/frontend-web.tar.gz"

mkdir -p "$artifact_dir"

(
  cd "$repo_root/frontend"
  flutter pub get
  flutter build web --release --dart-define=API_URL=
)

tar -C "$repo_root/frontend/build/web" -czf "$archive" .

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$archive" | awk '{print $1}' > "$artifact_dir/frontend-web.sha256"
else
  shasum -a 256 "$archive" | awk '{print $1}' > "$artifact_dir/frontend-web.sha256"
fi

"$repo_root/scripts/frontend-source-hash.sh" \
  > "$artifact_dir/frontend-source.sha256"

echo "Frontend release artifact created:"
echo "  $archive"
echo "Commit deploy/artifacts together with the frontend source changes."
